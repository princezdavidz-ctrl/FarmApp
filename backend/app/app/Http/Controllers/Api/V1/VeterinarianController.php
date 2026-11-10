<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\MpesaGatewayException;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\VeterinarianProfile;
use App\Models\VeterinaryPayment;
use App\Models\VeterinarySubscriptionPlan;
use App\Services\Payments\MpesaService;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use RuntimeException;
use Throwable;

class VeterinarianController extends Controller
{
    public function apply(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:30', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'license_number' => ['required', 'string', 'max:100', 'unique:veterinarian_profiles,license_number'],
            'clinic_name' => ['required', 'string', 'max:255'],
            'county' => ['required', 'string', 'max:100'],
            'specialization' => ['nullable', 'string', 'max:150'],
            'years_experience' => ['required', 'integer', 'min:0', 'max:80'],
        ]);

        $profile = DB::transaction(function () use ($data): VeterinarianProfile {
            $user = User::create([
                'name' => $data['name'],
                'email' => $data['email'],
                'phone' => $data['phone'],
                'password' => Hash::make($data['password']),
                'role' => 'veterinarian',
            ]);

            return VeterinarianProfile::create([
                ...collect($data)->except(['name', 'email', 'phone', 'password'])->all(),
                'user_id' => $user->id,
                'reference' => (string) Str::uuid(),
                'status' => 'pending',
            ]);
        });

        return response()->json([
            'application' => $this->applicationData($profile),
        ], 201);
    }

    public function applicationStatus(string $reference): JsonResponse
    {
        $profile = VeterinarianProfile::query()->where('reference', $reference)->firstOrFail();

        return response()->json(['application' => $this->applicationData($profile)]);
    }

    public function me(Request $request): JsonResponse
    {
        $profile = $this->profileFor($request);
        $profile->load('user:id,name,email,phone');

        return response()->json([
            'veterinarian' => [
                ...$this->applicationData($profile),
                'name' => $profile->user->name,
                'email' => $profile->user->email,
                'phone' => $profile->user->phone,
                'license_number' => $profile->license_number,
                'clinic_name' => $profile->clinic_name,
                'county' => $profile->county,
                'specialization' => $profile->specialization,
                'years_experience' => $profile->years_experience,
                'review_note' => $profile->review_note,
                'subscription_paid_at' => $profile->subscription_paid_at?->toIso8601String(),
                'subscription_expires_at' => $profile->subscription_expires_at?->toIso8601String(),
            ],
        ]);
    }

    public function plans(Request $request): JsonResponse
    {
        $profile = $this->profileFor($request);
        abort_unless($profile->status === 'approved', 403, 'Your application is awaiting approval.');

        return response()->json([
            'data' => VeterinarySubscriptionPlan::query()
                ->where('active', true)
                ->orderBy('amount')
                ->get(['code', 'name', 'description', 'amount', 'currency', 'duration_days']),
        ]);
    }

    public function crmPlans(Request $request): JsonResponse
    {
        $this->authorizeReviewer($request);

        return response()->json([
            'data' => VeterinarySubscriptionPlan::query()->orderBy('amount')->get(),
        ]);
    }

    public function storePlan(Request $request): JsonResponse
    {
        $this->authorizeReviewer($request);
        $data = $request->validate([
            'code' => ['required', 'string', 'max:50', 'alpha_dash', 'unique:veterinary_subscription_plans,code'],
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'amount' => ['required', 'numeric', 'gt:0', 'max:9999999999.99'],
            'currency' => ['required', Rule::in(['KES'])],
            'duration_days' => ['required', 'integer', 'min:1', 'max:3650'],
            'active' => ['sometimes', 'boolean'],
        ]);

        return response()->json([
            'data' => VeterinarySubscriptionPlan::create($data),
        ], 201);
    }

    public function updatePlan(Request $request, VeterinarySubscriptionPlan $veterinarySubscriptionPlan): JsonResponse
    {
        $this->authorizeReviewer($request);
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'amount' => ['sometimes', 'required', 'numeric', 'gt:0', 'max:9999999999.99'],
            'currency' => ['sometimes', 'required', Rule::in(['KES'])],
            'duration_days' => ['sometimes', 'required', 'integer', 'min:1', 'max:3650'],
            'active' => ['sometimes', 'required', 'boolean'],
        ]);
        $veterinarySubscriptionPlan->update($data);

        return response()->json(['data' => $veterinarySubscriptionPlan->fresh()]);
    }

    public function pay(Request $request, MpesaService $mpesa): JsonResponse
    {
        $profile = $this->profileFor($request);
        abort_unless($profile->status === 'approved', 403, 'Your veterinary account must be approved before subscribing.');
        $data = $request->validate([
            'plan' => ['required', 'string', Rule::exists('veterinary_subscription_plans', 'code')->where('active', true)],
            'phone' => ['nullable', 'string', 'regex:/^(\+?254|0)[0-9\s-]{9,}$/'],
        ]);
        $plan = VeterinarySubscriptionPlan::query()
            ->where('code', $data['plan'])
            ->where('active', true)
            ->firstOrFail();
        abort_unless(strtoupper($plan->currency) === 'KES', 422, 'M-Pesa payments require a KES subscription plan.');
        $phone = $this->normalizeKenyanPhone($data['phone'] ?? $request->user()->phone);
        abort_unless($phone !== null, 422, 'Use a valid Kenyan M-Pesa phone number.');

        $payment = VeterinaryPayment::create([
            'veterinarian_profile_id' => $profile->id,
            'user_id' => $request->user()->id,
            'plan_code' => $plan->code,
            'duration_days' => $plan->duration_days,
            'amount' => $plan->amount,
            'currency' => $plan->currency,
            'phone' => $phone,
            'status' => 'pending',
        ]);

        try {
            $response = $mpesa->initiate($payment);
            $payment->update([
                'merchant_request_id' => $response['MerchantRequestID'],
                'checkout_request_id' => $response['CheckoutRequestID'],
                'result_description' => $response['CustomerMessage'] ?? null,
            ]);
        } catch (MpesaGatewayException $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'Unable to start M-Pesa payment.']);
            Log::warning('Safaricom rejected a veterinary subscription payment.', [
                'payment_id' => $payment->id,
                'stage' => $exception->stage,
                'upstream_status' => $exception->upstreamStatus,
                'provider_code' => $exception->providerCode,
                'provider_request_id' => $exception->requestId,
            ]);

            return response()->json([
                'message' => 'Safaricom could not start the payment. Please try again.',
                'error' => 'mpesa_upstream_error',
                'reference' => $exception->requestId,
            ], 502);
        } catch (ConnectionException $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'Unable to connect to M-Pesa.']);
            Log::warning('Could not connect to Safaricom for veterinary subscription payment.', [
                'payment_id' => $payment->id,
                'message' => $exception->getMessage(),
            ]);

            return response()->json(['message' => 'Could not connect to Safaricom.', 'error' => 'mpesa_connection_error'], 502);
        } catch (RuntimeException $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'M-Pesa configuration error.']);
            Log::error('Veterinary M-Pesa configuration or response error.', [
                'payment_id' => $payment->id,
                'message' => $exception->getMessage(),
            ]);

            return response()->json(['message' => 'M-Pesa is not ready. Please contact support.', 'error' => 'mpesa_configuration_error'], 503);
        } catch (Throwable $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'Unable to start M-Pesa payment.']);
            throw $exception;
        }

        return response()->json(['payment' => $this->paymentData($payment->fresh())], 201);
    }

    public function payment(Request $request, VeterinaryPayment $payment): JsonResponse
    {
        abort_unless($payment->user_id === $request->user()->id, 404);

        return response()->json(['payment' => $this->paymentData($payment)]);
    }

    public function reviewQueue(Request $request): JsonResponse
    {
        $this->authorizeReviewer($request);

        $profiles = VeterinarianProfile::query()
            ->with('user:id,name,email,phone')
            ->where('status', 'pending')
            ->latest()
            ->paginate(30);

        return response()->json([
            'data' => $profiles->getCollection()->map(fn (VeterinarianProfile $profile): array => [
                ...$this->applicationData($profile),
                'name' => $profile->user->name,
                'email' => $profile->user->email,
                'phone' => $profile->user->phone,
                'license_number' => $profile->license_number,
                'clinic_name' => $profile->clinic_name,
                'county' => $profile->county,
                'specialization' => $profile->specialization,
                'years_experience' => $profile->years_experience,
            ]),
            'meta' => ['current_page' => $profiles->currentPage(), 'last_page' => $profiles->lastPage()],
        ]);
    }

    public function review(Request $request, VeterinarianProfile $veterinarianProfile): JsonResponse
    {
        $this->authorizeReviewer($request);
        $data = $request->validate([
            'status' => ['required', Rule::in(['approved', 'rejected'])],
            'review_note' => ['nullable', 'string', 'max:2000'],
        ]);
        abort_unless($veterinarianProfile->status === 'pending', 409, 'This application has already been reviewed.');

        $veterinarianProfile->update([
            'status' => $data['status'],
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
            'review_note' => $data['review_note'] ?? null,
        ]);

        return response()->json(['application' => $this->applicationData($veterinarianProfile->fresh())]);
    }

    private function profileFor(Request $request): VeterinarianProfile
    {
        abort_unless($request->user()->role === 'veterinarian', 403, 'This account is not a veterinarian account.');

        return $request->user()->veterinarianProfile()->firstOrFail();
    }

    private function authorizeReviewer(Request $request): void
    {
        abort_unless(
            $request->user()->crm_role === 'admin' || $request->user()->is_global_crm_admin,
            403,
            'Only a CRM administrator can review veterinary applications.',
        );
    }

    private function applicationData(VeterinarianProfile $profile): array
    {
        return [
            'reference' => $profile->reference,
            'status' => $profile->status,
            'review_note' => $profile->review_note,
            'created_at' => $profile->created_at?->toIso8601String(),
        ];
    }

    private function paymentData(VeterinaryPayment $payment): array
    {
        return [
            'id' => (string) $payment->id,
            'plan_code' => $payment->plan_code,
            'amount' => $payment->amount,
            'currency' => $payment->currency,
            'status' => $payment->status,
            'result_description' => $payment->result_description,
            'paid_at' => $payment->paid_at?->toIso8601String(),
        ];
    }

    private function normalizeKenyanPhone(string $phone): ?string
    {
        $digits = preg_replace('/\D+/', '', $phone);
        if (str_starts_with($digits, '0')) {
            $digits = '254'.substr($digits, 1);
        }

        return preg_match('/^254[17]\d{8}$/', $digits) ? $digits : null;
    }
}
