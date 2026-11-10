<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\MpesaGatewayException;
use App\Http\Controllers\Controller;
use App\Models\DriverPayment;
use App\Models\DriverProfile;
use App\Models\DriverSubscriptionPlan;
use App\Models\User;
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

class AnimalDriverController extends Controller
{
    public function apply(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:30', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'driver_license_number' => ['required', 'string', 'max:100', 'unique:driver_profiles,driver_license_number'],
            'county' => ['required', 'string', 'max:100'],
            'service_types' => ['required', 'array', 'min:1'],
            'service_types.*' => ['required', Rule::in(['herd', 'supplies'])],
            'vehicle_type' => ['required', 'string', 'max:100'],
            'vehicle_registration_number' => ['required', 'string', 'max:30', 'unique:driver_profiles,vehicle_registration_number'],
            'capacity_description' => ['required', 'string', 'max:255'],
        ]);

        $profile = DB::transaction(function () use ($data): DriverProfile {
            $user = User::create([
                'name' => $data['name'],
                'email' => $data['email'],
                'phone' => $data['phone'],
                'password' => Hash::make($data['password']),
                'role' => 'animalDriver',
            ]);

            return DriverProfile::create([
                'user_id' => $user->id,
                'reference' => (string) Str::uuid(),
                'driver_license_number' => $data['driver_license_number'],
                'county' => $data['county'],
                'service_types' => implode(',', array_unique($data['service_types'])),
                'vehicle_type' => $data['vehicle_type'],
                'vehicle_registration_number' => strtoupper($data['vehicle_registration_number']),
                'capacity_description' => $data['capacity_description'],
                'status' => 'pending',
            ]);
        });

        return response()->json(['application' => $this->applicationData($profile)], 201);
    }

    public function applicationStatus(string $reference): JsonResponse
    {
        $profile = DriverProfile::query()->where('reference', $reference)->firstOrFail();

        return response()->json(['application' => $this->applicationData($profile)]);
    }

    public function me(Request $request): JsonResponse
    {
        $profile = $this->profileFor($request);
        $profile->load('user:id,name,email,phone');

        return response()->json(['driver' => [
            ...$this->applicationData($profile),
            'name' => $profile->user->name,
            'email' => $profile->user->email,
            'phone' => $profile->user->phone,
            'driver_license_number' => $profile->driver_license_number,
            'county' => $profile->county,
            'service_types' => explode(',', $profile->service_types),
            'vehicle_type' => $profile->vehicle_type,
            'vehicle_registration_number' => $profile->vehicle_registration_number,
            'capacity_description' => $profile->capacity_description,
            'subscription_paid_at' => $profile->subscription_paid_at?->toIso8601String(),
            'subscription_expires_at' => $profile->subscription_expires_at?->toIso8601String(),
            'latitude' => $profile->latitude,
            'longitude' => $profile->longitude,
            'available' => $profile->available,
            'location_updated_at' => $profile->location_updated_at?->toIso8601String(),
        ]]);
    }

    public function plans(Request $request): JsonResponse
    {
        abort_unless($this->profileFor($request)->status === 'approved', 403, 'Your driver application is awaiting approval.');

        return response()->json(['data' => DriverSubscriptionPlan::query()
            ->where('active', true)->orderBy('amount')
            ->get(['code', 'name', 'description', 'amount', 'currency', 'duration_days'])]);
    }

    public function pay(Request $request, MpesaService $mpesa): JsonResponse
    {
        $profile = $this->profileFor($request);
        abort_unless($profile->status === 'approved', 403, 'Your driver account must be approved before subscribing.');
        $data = $request->validate([
            'plan' => ['required', 'string', Rule::exists('driver_subscription_plans', 'code')->where('active', true)],
            'phone' => ['nullable', 'string', 'regex:/^(\+?254|0)[0-9\s-]{9,}$/'],
        ]);
        $plan = DriverSubscriptionPlan::query()->where('code', $data['plan'])->where('active', true)->firstOrFail();
        abort_unless(strtoupper($plan->currency) === 'KES', 422, 'M-Pesa payments require a KES subscription plan.');
        $phone = $this->normalizeKenyanPhone($data['phone'] ?? $request->user()->phone);
        abort_unless($phone !== null, 422, 'Use a valid Kenyan M-Pesa phone number.');
        $payment = DriverPayment::create([
            'driver_profile_id' => $profile->id,
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
            Log::warning('Safaricom rejected an animal driver subscription payment.', [
                'payment_id' => $payment->id,
                'stage' => $exception->stage,
                'upstream_status' => $exception->upstreamStatus,
                'provider_code' => $exception->providerCode,
                'provider_request_id' => $exception->requestId,
            ]);

            return response()->json(['message' => 'Safaricom could not start the payment.', 'error' => 'mpesa_upstream_error'], 502);
        } catch (ConnectionException $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'Unable to connect to M-Pesa.']);
            Log::warning('Could not connect to Safaricom for animal driver payment.', [
                'payment_id' => $payment->id,
                'message' => $exception->getMessage(),
            ]);

            return response()->json(['message' => 'Could not connect to Safaricom.', 'error' => 'mpesa_connection_error'], 502);
        } catch (RuntimeException $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'M-Pesa configuration error.']);
            Log::error('Animal driver M-Pesa configuration error.', [
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

    public function payment(Request $request, DriverPayment $payment): JsonResponse
    {
        abort_unless($payment->user_id === $request->user()->id, 404);

        return response()->json(['payment' => $this->paymentData($payment)]);
    }

    public function updateLocation(Request $request): JsonResponse
    {
        $profile = $this->profileFor($request);
        abort_unless($this->hasActiveSubscription($profile), 403, 'An active driver subscription is required to share your location.');
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'available' => ['required', 'boolean'],
        ]);
        $profile->update([
            ...$data,
            'location_updated_at' => now(),
        ]);

        return response()->json(['driver' => [
            'latitude' => $profile->latitude,
            'longitude' => $profile->longitude,
            'available' => $profile->available,
            'location_updated_at' => $profile->location_updated_at?->toIso8601String(),
        ]]);
    }

    public function nearby(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius_km' => ['sometimes', 'numeric', 'min:1', 'max:100'],
            'service_type' => ['sometimes', Rule::in(['herd', 'supplies'])],
            'vehicle_type' => ['sometimes', 'string', 'max:100'],
        ]);
        $lat = (float) $filters['latitude'];
        $lng = (float) $filters['longitude'];
        $radius = (float) ($filters['radius_km'] ?? 25);
        $latDelta = $radius / 111.045;
        $lngDelta = $radius / max(111.045 * cos(deg2rad($lat)), 0.01);
        $drivers = DriverProfile::query()->with('user:id,name,phone')
            ->where('status', 'approved')
            ->where('available', true)
            ->where('subscription_expires_at', '>', now())
            ->where('location_updated_at', '>=', now()->subMinutes(15))
            ->whereBetween('latitude', [$lat - $latDelta, $lat + $latDelta])
            ->whereBetween('longitude', [$lng - $lngDelta, $lng + $lngDelta])
            ->when(isset($filters['service_type']), fn ($query) => $query->where('service_types', 'like', '%'.$filters['service_type'].'%'))
            ->when(isset($filters['vehicle_type']), fn ($query) => $query->where('vehicle_type', $filters['vehicle_type']))
            ->limit(100)
            ->get()
            ->map(function (DriverProfile $driver) use ($lat, $lng): array {
                $distance = 6371 * 2 * asin(sqrt(
                    pow(sin(deg2rad(((float) $driver->latitude - $lat) / 2)), 2)
                    + cos(deg2rad($lat)) * cos(deg2rad((float) $driver->latitude))
                    * pow(sin(deg2rad(((float) $driver->longitude - $lng) / 2)), 2),
                ));

                return [
                    'id' => (string) $driver->id,
                    'name' => $driver->user->name,
                    'phone' => $driver->user->phone,
                    'county' => $driver->county,
                    'service_types' => explode(',', $driver->service_types),
                    'vehicle_type' => $driver->vehicle_type,
                    'capacity_description' => $driver->capacity_description,
                    'latitude' => (float) $driver->latitude,
                    'longitude' => (float) $driver->longitude,
                    'distance_km' => round($distance, 1),
                ];
            })
            ->filter(fn (array $driver): bool => $driver['distance_km'] <= $radius)
            ->sortBy('distance_km')
            ->values();

        return response()->json(['data' => $drivers]);
    }

    public function reviewQueue(Request $request): JsonResponse
    {
        $this->authorizeReviewer($request);
        $profiles = DriverProfile::query()->with('user:id,name,email,phone')
            ->where('status', 'pending')->latest()->paginate(30);

        return response()->json([
            'data' => $profiles->getCollection()->map(fn (DriverProfile $profile): array => [
                ...$this->applicationData($profile),
                'name' => $profile->user->name,
                'email' => $profile->user->email,
                'phone' => $profile->user->phone,
                'driver_license_number' => $profile->driver_license_number,
                'county' => $profile->county,
                'service_types' => explode(',', $profile->service_types),
                'vehicle_type' => $profile->vehicle_type,
                'vehicle_registration_number' => $profile->vehicle_registration_number,
                'capacity_description' => $profile->capacity_description,
            ]),
            'meta' => ['current_page' => $profiles->currentPage(), 'last_page' => $profiles->lastPage()],
        ]);
    }

    public function review(Request $request, DriverProfile $driverProfile): JsonResponse
    {
        $this->authorizeReviewer($request);
        $data = $request->validate([
            'status' => ['required', Rule::in(['approved', 'rejected'])],
            'review_note' => ['nullable', 'string', 'max:2000'],
        ]);
        abort_unless($driverProfile->status === 'pending', 409, 'This application has already been reviewed.');
        $driverProfile->update([
            'status' => $data['status'],
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
            'review_note' => $data['review_note'] ?? null,
        ]);

        return response()->json(['application' => $this->applicationData($driverProfile->fresh())]);
    }

    public function crmPlans(Request $request): JsonResponse
    {
        $this->authorizeReviewer($request);

        return response()->json(['data' => DriverSubscriptionPlan::query()->orderBy('amount')->get()]);
    }

    public function storePlan(Request $request): JsonResponse
    {
        $this->authorizeReviewer($request);
        $data = $request->validate([
            'code' => ['required', 'string', 'max:50', 'alpha_dash', 'unique:driver_subscription_plans,code'],
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'amount' => ['required', 'numeric', 'gt:0', 'max:9999999999.99'],
            'currency' => ['required', Rule::in(['KES'])],
            'duration_days' => ['required', 'integer', 'min:1', 'max:3650'],
            'active' => ['sometimes', 'boolean'],
        ]);

        return response()->json(['data' => DriverSubscriptionPlan::create($data)], 201);
    }

    public function updatePlan(Request $request, DriverSubscriptionPlan $driverSubscriptionPlan): JsonResponse
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
        $driverSubscriptionPlan->update($data);

        return response()->json(['data' => $driverSubscriptionPlan->fresh()]);
    }

    private function profileFor(Request $request): DriverProfile
    {
        abort_unless($request->user()->role === 'animalDriver', 403, 'This account is not an animal driver account.');

        return $request->user()->driverProfile()->firstOrFail();
    }

    private function authorizeReviewer(Request $request): void
    {
        abort_unless(
            $request->user()->crm_role === 'admin' || $request->user()->is_global_crm_admin,
            403,
            'Only a CRM administrator can manage animal driver accounts.',
        );
    }

    private function hasActiveSubscription(DriverProfile $profile): bool
    {
        return $profile->status === 'approved'
            && $profile->subscription_expires_at !== null
            && $profile->subscription_expires_at->isFuture();
    }

    private function applicationData(DriverProfile $profile): array
    {
        return [
            'reference' => $profile->reference,
            'status' => $profile->status,
            'review_note' => $profile->review_note,
            'created_at' => $profile->created_at?->toIso8601String(),
        ];
    }

    private function paymentData(DriverPayment $payment): array
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
