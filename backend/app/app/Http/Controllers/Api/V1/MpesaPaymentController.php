<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Exceptions\MpesaGatewayException;
use App\Http\Requests\Farm\StoreMpesaPaymentRequest;
use App\Models\Farm;
use App\Models\Payment;
use App\Models\DriverPayment;
use App\Models\SubscriptionPlan;
use App\Models\SupplierPayment;
use App\Models\VeterinaryPayment;
use App\Services\Payments\MpesaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Http\Client\ConnectionException;
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

    public function callback(Request $request): JsonResponse
    {
        $secret = config('services.mpesa.callback_secret');
        abort_unless(
            is_string($secret) && strlen($secret) >= 32 &&
            hash_equals($secret, (string) $request->query('callback_token')),
            403,
            'Invalid payment callback token.',
        );

        $callback = $request->input('Body.stkCallback', []);
        $checkoutId = $callback['CheckoutRequestID'] ?? null;
        $resultCode = (int) ($callback['ResultCode'] ?? 1);
        $payment = $checkoutId
            ? (Payment::where('checkout_request_id', $checkoutId)->first()
                ?? VeterinaryPayment::where('checkout_request_id', $checkoutId)->first()
                ?? DriverPayment::where('checkout_request_id', $checkoutId)->first()
                ?? SupplierPayment::where('checkout_request_id', $checkoutId)->first())
            : null;

        if (! $payment) {
            return response()->json(['ResultCode' => 0, 'ResultDesc' => 'Accepted']);
        }

        DB::transaction(function () use ($payment, $callback, $resultCode): void {
            if ($payment->status === 'paid') {
                return;
            }

            if ($resultCode !== 0) {
                $payment->update([
                    'status' => 'failed',
                    'result_description' => $callback['ResultDesc'] ?? 'Payment failed.',
                ]);

                return;
            }

            $items = collect($callback['CallbackMetadata']['Item'] ?? [])->keyBy('Name');
            $payment->update([
                'status' => 'paid',
                'mpesa_receipt' => $items->get('MpesaReceiptNumber')['Value'] ?? null,
                'result_description' => $callback['ResultDesc'] ?? 'Payment received.',
                'paid_at' => now(),
            ]);
            if ($payment instanceof DriverPayment) {
                $profile = $payment->driverProfile;
                $now = now();
                $base = $profile->subscription_expires_at?->isFuture()
                    ? $profile->subscription_expires_at->copy()
                    : $now;
                $profile->update([
                    'subscription_paid_at' => $now,
                    'subscription_expires_at' => $base->addDays(max($payment->duration_days, 1)),
                ]);
            } elseif ($payment instanceof VeterinaryPayment) {
                $profile = $payment->veterinarianProfile;
                $now = now();
                $base = $profile->subscription_expires_at?->isFuture()
                    ? $profile->subscription_expires_at->copy()
                    : $now;
                $profile->update([
                    'subscription_paid_at' => $now,
                    'subscription_expires_at' => $base->addDays(max($payment->duration_days, 1)),
                ]);
            } elseif ($payment instanceof SupplierPayment) {
                $profile = $payment->supplierProfile;
                $now = now();
                $base = $profile->subscription_expires_at?->isFuture()
                    ? $profile->subscription_expires_at->copy()
                    : $now;
                $profile->update([
                    'subscription_paid_at' => $now,
                    'subscription_expires_at' => $base->addDays(max($payment->duration_days, 1)),
                ]);
            } else {
                $payment->farm()->update(['subscription_plan' => $payment->plan_code]);
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
