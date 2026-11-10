<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\MpesaGatewayException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\StoreMpesaPaymentRequest;
use App\Models\DriverPayment;
use App\Models\Farm;
use App\Models\Payment;
use App\Models\SubscriptionPlan;
use App\Models\SupplierPayment;
use App\Models\VeterinaryPayment;
use App\Services\Payments\MpesaService;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use RuntimeException;
use Throwable;

class MpesaPaymentController extends Controller
{
    public function store(StoreMpesaPaymentRequest $request, Farm $farm, MpesaService $mpesa): JsonResponse
    {
        $user = $request->user();
        abort_unless($user->farms()->whereKey($farm->id)->exists(), 403, 'You do not belong to this farm.');

        $count = (int) ($farm->mother_pig_count ?? 0);
        $plan = SubscriptionPlan::query()->where('code', $request->string('plan'))->where('active', true)->firstOrFail();
        abort_if($count < 1, 422, 'Enter the number of mother pigs before paying.');
        abort_if($plan->pig_limit !== null && $count > $plan->pig_limit, 422, 'This plan does not cover the farm herd size.');
        abort_if(strtoupper($plan->currency) !== 'KES', 422, 'M-Pesa payments require a KES subscription plan.');

        $phone = $request->normalizedPhone() ?? $this->normalizeKenyanPhone($user->phone);
        abort_unless($phone, 422, 'Use a valid Kenyan M-Pesa phone number.');

        $payment = Payment::create([
            'farm_id' => $farm->id,
            'user_id' => $user->id,
            'plan_code' => $plan->code,
            'mother_pig_count' => $count,
            'amount' => $plan->amount,
            'currency' => $plan->currency,
            'phone' => $phone,
            'status' => 'pending',
        ]);

        try {
            $response = $mpesa->initiate($payment);
            $payment->update([
                'merchant_request_id' => $response['MerchantRequestID'] ?? null,
                'checkout_request_id' => $response['CheckoutRequestID'] ?? null,
                'result_description' => $response['CustomerMessage'] ?? null,
            ]);
        } catch (MpesaGatewayException $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'Unable to start M-Pesa payment.']);

            Log::warning('Safaricom rejected or failed a payment initiation request.', [
                'payment_id' => $payment->id,
                'farm_id' => $farm->id,
                'stage' => $exception->stage,
                'upstream_status' => $exception->upstreamStatus,
                'provider_code' => $exception->providerCode,
                'provider_request_id' => $exception->requestId,
                'provider_message' => $exception->providerMessage,
            ]);

            return response()->json([
                'message' => 'Safaricom could not start the payment. Check that the Daraja environment, shortcode, and credentials belong to the same app.',
                'error' => 'mpesa_upstream_error',
                'provider_code' => $exception->providerCode,
                'reference' => $exception->requestId,
            ], 502);
        } catch (ConnectionException $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'Unable to connect to M-Pesa.']);
            Log::warning('Could not connect to the Safaricom payment gateway.', [
                'payment_id' => $payment->id,
                'farm_id' => $farm->id,
                'message' => $exception->getMessage(),
            ]);

            return response()->json([
                'message' => 'Could not connect to Safaricom. Please try again later.',
                'error' => 'mpesa_connection_error',
            ], 502);
        } catch (RuntimeException $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'M-Pesa payment configuration error.']);
            Log::error('M-Pesa payment configuration or response error.', [
                'payment_id' => $payment->id,
                'farm_id' => $farm->id,
                'message' => $exception->getMessage(),
            ]);

            return response()->json([
                'message' => 'M-Pesa is not ready to process this payment. Please contact support.',
                'error' => 'mpesa_configuration_error',
            ], 503);
        } catch (Throwable $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'Unable to start M-Pesa payment.']);
            throw $exception;
        }

        return response()->json(['payment' => $payment->fresh()], 201);
    }

    public function callback(Request $request, MpesaService $mpesa): JsonResponse
    {
        $secret = config('services.mpesa.callback_secret');
        abort_unless(
            is_string($secret) && strlen($secret) >= 32 &&
            hash_equals($secret, (string) $request->query('callback_token')),
            403,
            'Invalid payment callback token.',
        );

        $callback = $request->input('Body.stkCallback', []);
        if (! is_array($callback)) {
            return response()->json(['message' => 'Invalid payment callback.'], 422);
        }

        $checkoutId = $callback['CheckoutRequestID'] ?? null;
        $payment = $checkoutId
            ? (Payment::where('checkout_request_id', $checkoutId)->first()
                ?? VeterinaryPayment::where('checkout_request_id', $checkoutId)->first()
                ?? DriverPayment::where('checkout_request_id', $checkoutId)->first()
                ?? SupplierPayment::where('checkout_request_id', $checkoutId)->first())
            : null;

        if (! $payment) {
            return response()->json(['ResultCode' => 0, 'ResultDesc' => 'Accepted']);
        }

        if ($payment->status === 'paid') {
            return response()->json(['ResultCode' => 0, 'ResultDesc' => 'Accepted']);
        }

        try {
            $providerResultCode = $mpesa->queryResultCode($payment);
        } catch (Throwable $exception) {
            Log::warning('Could not verify an M-Pesa callback with Safaricom.', [
                'payment_id' => $payment->id,
                'payment_type' => class_basename($payment),
                'farm_id' => $payment instanceof Payment ? $payment->farm_id : null,
                'message' => $exception->getMessage(),
            ]);

            return response()->json(['message' => 'Payment verification is temporarily unavailable.'], 503);
        }

        $resultCode = filter_var($callback['ResultCode'] ?? null, FILTER_VALIDATE_INT);
        if ($resultCode === false || $resultCode !== $providerResultCode) {
            Log::warning('Rejected an M-Pesa callback that did not match provider verification.', [
                'payment_id' => $payment->id,
                'payment_type' => class_basename($payment),
                'farm_id' => $payment instanceof Payment ? $payment->farm_id : null,
            ]);

            return response()->json(['message' => 'Payment callback could not be verified.'], 422);
        }

        $metadata = collect($callback['CallbackMetadata']['Item'] ?? [])
            ->filter(fn ($item): bool => is_array($item) && isset($item['Name']))
            ->keyBy('Name');
        $receipt = data_get($metadata->get('MpesaReceiptNumber'), 'Value');
        if ($resultCode === 0 &&
            ((int) data_get($metadata->get('Amount'), 'Value', -1) !== (int) ceil((float) $payment->amount) ||
                blank($receipt))) {
            Log::warning('Rejected an incomplete or mismatched successful M-Pesa callback.', [
                'payment_id' => $payment->id,
                'payment_type' => class_basename($payment),
                'farm_id' => $payment instanceof Payment ? $payment->farm_id : null,
            ]);

            return response()->json(['message' => 'Payment callback could not be verified.'], 422);
        }

        DB::transaction(function () use ($payment, $callback, $resultCode, $receipt): void {
            $lockedPayment = $payment::query()->lockForUpdate()->find($payment->id);
            if ($lockedPayment === null || $lockedPayment->status === 'paid') {
                return;
            }

            if ($resultCode !== 0) {
                $lockedPayment->update([
                    'status' => 'failed',
                    'result_description' => $callback['ResultDesc'] ?? 'Payment failed.',
                ]);

                return;
            }

            $lockedPayment->update([
                'status' => 'paid',
                'mpesa_receipt' => $receipt,
                'result_description' => $callback['ResultDesc'] ?? 'Payment received.',
                'paid_at' => now(),
            ]);
            if ($lockedPayment instanceof DriverPayment) {
                $profile = $lockedPayment->driverProfile;
                $now = now();
                $base = $profile->subscription_expires_at?->isFuture()
                    ? $profile->subscription_expires_at->copy()
                    : $now;
                $profile->update([
                    'subscription_paid_at' => $now,
                    'subscription_expires_at' => $base->addDays(max($lockedPayment->duration_days, 1)),
                ]);
            } elseif ($lockedPayment instanceof VeterinaryPayment) {
                $profile = $lockedPayment->veterinarianProfile;
                $now = now();
                $base = $profile->subscription_expires_at?->isFuture()
                    ? $profile->subscription_expires_at->copy()
                    : $now;
                $profile->update([
                    'subscription_paid_at' => $now,
                    'subscription_expires_at' => $base->addDays(max($lockedPayment->duration_days, 1)),
                ]);
            } elseif ($lockedPayment instanceof SupplierPayment) {
                $profile = $lockedPayment->supplierProfile;
                $now = now();
                $base = $profile->subscription_expires_at?->isFuture()
                    ? $profile->subscription_expires_at->copy()
                    : $now;
                $profile->update([
                    'subscription_paid_at' => $now,
                    'subscription_expires_at' => $base->addDays(max($lockedPayment->duration_days, 1)),
                ]);
            } else {
                $lockedPayment->farm()->update(['subscription_plan' => $lockedPayment->plan_code]);
            }
        });

        return response()->json(['ResultCode' => 0, 'ResultDesc' => 'Accepted']);
    }

    private function normalizeKenyanPhone(string $phone): ?string
    {
        $normalized = preg_replace('/\D+/', '', $phone);
        if (str_starts_with($normalized, '0')) {
            $normalized = '254'.substr($normalized, 1);
        }

        return preg_match('/^254[17]\d{8}$/', $normalized) ? $normalized : null;
    }
}
