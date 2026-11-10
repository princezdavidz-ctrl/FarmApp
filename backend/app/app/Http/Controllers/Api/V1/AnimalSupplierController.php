<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\MpesaGatewayException;
use App\Http\Controllers\Controller;
use App\Models\SupplierPayment;
use App\Models\SupplierProduct;
use App\Models\SupplierProfile;
use App\Models\SupplierSubscriptionPlan;
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

class AnimalSupplierController extends Controller
{
    public function publicProducts(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['sometimes', 'string', 'max:120'],
            'category' => ['sometimes', 'string', 'max:100'],
            'county' => ['sometimes', 'string', 'max:100'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
        $products = SupplierProduct::query()
            ->with('supplierProfile:id,business_name,county')
            ->where('active', true)
            ->whereHas('supplierProfile', fn ($query) => $query
                ->where('status', 'approved')
                ->where('subscription_expires_at', '>', now()))
            ->when(
                isset($filters['search']),
                fn ($query) => $query->where(fn ($search) => $search
                    ->where('name', 'like', '%'.$filters['search'].'%')
                    ->orWhere('description', 'like', '%'.$filters['search'].'%')),
            )
            ->when(
                isset($filters['category']),
                fn ($query) => $query->where('category', $filters['category']),
            )
            ->when(
                isset($filters['county']),
                fn ($query) => $query->whereHas('supplierProfile', fn ($profile) => $profile
                    ->where('county', $filters['county'])),
            )
            ->latest()
            ->paginate($filters['per_page'] ?? 30);

        return response()->json([
            'data' => $products->getCollection()->map(fn (SupplierProduct $product): array => [
                'id' => (string) $product->id,
                'name' => $product->name,
                'category' => $product->category,
                'description' => $product->description,
                'price' => $product->price,
                'currency' => $product->currency,
                'unit' => $product->unit,
                'stock_quantity' => $product->stock_quantity,
                'supplier_name' => $product->supplierProfile->business_name,
                'county' => $product->supplierProfile->county,
            ])->values(),
            'meta' => [
                'current_page' => $products->currentPage(),
                'last_page' => $products->lastPage(),
                'per_page' => $products->perPage(),
                'total' => $products->total(),
            ],
        ]);
    }

    public function apply(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:30', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'business_registration_number' => ['required', 'string', 'max:100', 'unique:supplier_profiles,business_registration_number'],
            'business_name' => ['required', 'string', 'max:255'],
            'county' => ['required', 'string', 'max:100'],
            'product_categories' => ['required', 'string', 'max:255'],
        ]);

        $profile = DB::transaction(function () use ($data): SupplierProfile {
            $user = User::create([
                'name' => $data['name'],
                'email' => $data['email'],
                'phone' => $data['phone'],
                'password' => Hash::make($data['password']),
                'role' => 'animalSupplier',
            ]);

            return SupplierProfile::create([
                ...collect($data)->only([
                    'business_registration_number', 'business_name', 'county', 'product_categories',
                ])->all(),
                'user_id' => $user->id,
                'reference' => (string) Str::uuid(),
                'status' => 'pending',
            ]);
        });

        return response()->json(['application' => $this->applicationData($profile)], 201);
    }

    public function applicationStatus(string $reference): JsonResponse
    {
        $profile = SupplierProfile::query()->where('reference', $reference)->firstOrFail();

        return response()->json(['application' => $this->applicationData($profile)]);
    }

    public function me(Request $request): JsonResponse
    {
        $profile = $this->profileFor($request);
        $profile->load('user:id,name,email,phone');

        return response()->json([
            'supplier' => [
                ...$this->applicationData($profile),
                'name' => $profile->user->name,
                'email' => $profile->user->email,
                'phone' => $profile->user->phone,
                'business_registration_number' => $profile->business_registration_number,
                'business_name' => $profile->business_name,
                'county' => $profile->county,
                'product_categories' => $profile->product_categories,
                'subscription_paid_at' => $profile->subscription_paid_at?->toIso8601String(),
                'subscription_expires_at' => $profile->subscription_expires_at?->toIso8601String(),
            ],
        ]);
    }

    public function plans(Request $request): JsonResponse
    {
        abort_unless($this->profileFor($request)->status === 'approved', 403, 'Your supplier application is awaiting approval.');

        return response()->json([
            'data' => SupplierSubscriptionPlan::query()
                ->where('active', true)
                ->orderBy('amount')
                ->get(['code', 'name', 'description', 'amount', 'currency', 'duration_days']),
        ]);
    }

    public function pay(Request $request, MpesaService $mpesa): JsonResponse
    {
        $profile = $this->profileFor($request);
        abort_unless($profile->status === 'approved', 403, 'Your supplier account must be approved before subscribing.');
        $data = $request->validate([
            'plan' => ['required', 'string', Rule::exists('supplier_subscription_plans', 'code')->where('active', true)],
            'phone' => ['nullable', 'string', 'regex:/^(\+?254|0)[0-9\s-]{9,}$/'],
        ]);
        $plan = SupplierSubscriptionPlan::query()->where('code', $data['plan'])->where('active', true)->firstOrFail();
        abort_unless(strtoupper($plan->currency) === 'KES', 422, 'M-Pesa payments require a KES subscription plan.');
        $phone = $this->normalizeKenyanPhone($data['phone'] ?? $request->user()->phone);
        abort_unless($phone !== null, 422, 'Use a valid Kenyan M-Pesa phone number.');

        $payment = SupplierPayment::create([
            'supplier_profile_id' => $profile->id,
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
            Log::warning('Safaricom rejected an animal supplier subscription payment.', [
                'payment_id' => $payment->id,
                'stage' => $exception->stage,
                'upstream_status' => $exception->upstreamStatus,
                'provider_code' => $exception->providerCode,
                'provider_request_id' => $exception->requestId,
            ]);

            return response()->json(['message' => 'Safaricom could not start the payment.', 'error' => 'mpesa_upstream_error'], 502);
        } catch (ConnectionException $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'Unable to connect to M-Pesa.']);
            Log::warning('Could not connect to Safaricom for animal supplier payment.', [
                'payment_id' => $payment->id,
                'message' => $exception->getMessage(),
            ]);

            return response()->json(['message' => 'Could not connect to Safaricom.', 'error' => 'mpesa_connection_error'], 502);
        } catch (RuntimeException $exception) {
            $payment->update(['status' => 'failed', 'result_description' => 'M-Pesa configuration error.']);
            Log::error('Animal supplier M-Pesa configuration error.', [
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

    public function payment(Request $request, SupplierPayment $payment): JsonResponse
    {
        abort_unless($payment->user_id === $request->user()->id, 404);

        return response()->json(['payment' => $this->paymentData($payment)]);
    }

    public function products(Request $request): JsonResponse
    {
        $profile = $this->profileFor($request);
        abort_unless($this->hasActiveSubscription($profile), 403, 'An active supplier subscription is required to manage product listings.');

        return response()->json([
            'data' => $profile->products()->latest()->get(),
        ]);
    }

    public function storeProduct(Request $request): JsonResponse
    {
        $profile = $this->profileFor($request);
        abort_unless($this->hasActiveSubscription($profile), 403, 'An active supplier subscription is required to manage product listings.');
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'category' => ['required', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:4000'],
            'price' => ['required', 'numeric', 'gt:0', 'max:9999999999.99'],
            'currency' => ['required', Rule::in(['KES'])],
            'unit' => ['required', 'string', 'max:50'],
            'stock_quantity' => ['required', 'integer', 'min:0', 'max:100000000'],
            'active' => ['sometimes', 'boolean'],
        ]);
        $product = $profile->products()->create($data);

        return response()->json(['data' => $product], 201);
    }

    public function updateProduct(Request $request, SupplierProduct $supplierProduct): JsonResponse
    {
        $profile = $this->profileFor($request);
        abort_unless($supplierProduct->supplier_profile_id === $profile->id, 404);
        abort_unless($this->hasActiveSubscription($profile), 403, 'An active supplier subscription is required to manage product listings.');
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'category' => ['sometimes', 'required', 'string', 'max:100'],
            'description' => ['sometimes', 'nullable', 'string', 'max:4000'],
            'price' => ['sometimes', 'required', 'numeric', 'gt:0', 'max:9999999999.99'],
            'currency' => ['sometimes', 'required', Rule::in(['KES'])],
            'unit' => ['sometimes', 'required', 'string', 'max:50'],
            'stock_quantity' => ['sometimes', 'required', 'integer', 'min:0', 'max:100000000'],
            'active' => ['sometimes', 'required', 'boolean'],
        ]);
        $supplierProduct->update($data);

        return response()->json(['data' => $supplierProduct->fresh()]);
    }

    public function reviewQueue(Request $request): JsonResponse
    {
        $this->authorizeReviewer($request);
        $profiles = SupplierProfile::query()->with('user:id,name,email,phone')
            ->where('status', 'pending')->latest()->paginate(30);

        return response()->json([
            'data' => $profiles->getCollection()->map(fn (SupplierProfile $profile): array => [
                ...$this->applicationData($profile),
                'name' => $profile->user->name,
                'email' => $profile->user->email,
                'phone' => $profile->user->phone,
                'business_registration_number' => $profile->business_registration_number,
                'business_name' => $profile->business_name,
                'county' => $profile->county,
                'product_categories' => $profile->product_categories,
            ]),
            'meta' => ['current_page' => $profiles->currentPage(), 'last_page' => $profiles->lastPage()],
        ]);
    }

    public function review(Request $request, SupplierProfile $supplierProfile): JsonResponse
    {
        $this->authorizeReviewer($request);
        $data = $request->validate([
            'status' => ['required', Rule::in(['approved', 'rejected'])],
            'review_note' => ['nullable', 'string', 'max:2000'],
        ]);
        abort_unless($supplierProfile->status === 'pending', 409, 'This application has already been reviewed.');
        $supplierProfile->update([
            'status' => $data['status'],
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
            'review_note' => $data['review_note'] ?? null,
        ]);

        return response()->json(['application' => $this->applicationData($supplierProfile->fresh())]);
    }

    public function crmPlans(Request $request): JsonResponse
    {
        $this->authorizeReviewer($request);

        return response()->json(['data' => SupplierSubscriptionPlan::query()->orderBy('amount')->get()]);
    }

    public function storePlan(Request $request): JsonResponse
    {
        $this->authorizeReviewer($request);
        $data = $request->validate([
            'code' => ['required', 'string', 'max:50', 'alpha_dash', 'unique:supplier_subscription_plans,code'],
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'amount' => ['required', 'numeric', 'gt:0', 'max:9999999999.99'],
            'currency' => ['required', Rule::in(['KES'])],
            'duration_days' => ['required', 'integer', 'min:1', 'max:3650'],
            'active' => ['sometimes', 'boolean'],
        ]);

        return response()->json(['data' => SupplierSubscriptionPlan::create($data)], 201);
    }

    public function updatePlan(Request $request, SupplierSubscriptionPlan $supplierSubscriptionPlan): JsonResponse
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
        $supplierSubscriptionPlan->update($data);

        return response()->json(['data' => $supplierSubscriptionPlan->fresh()]);
    }

    private function profileFor(Request $request): SupplierProfile
    {
        abort_unless($request->user()->role === 'animalSupplier', 403, 'This account is not an animal supplier account.');

        return $request->user()->supplierProfile()->firstOrFail();
    }

    private function authorizeReviewer(Request $request): void
    {
        abort_unless(
            $request->user()->crm_role === 'admin' || $request->user()->is_global_crm_admin,
            403,
            'Only a CRM administrator can manage animal supplier accounts.',
        );
    }

    private function hasActiveSubscription(SupplierProfile $profile): bool
    {
        return $profile->status === 'approved'
            && $profile->subscription_expires_at !== null
            && $profile->subscription_expires_at->isFuture();
    }

    private function applicationData(SupplierProfile $profile): array
    {
        return [
            'reference' => $profile->reference,
            'status' => $profile->status,
            'review_note' => $profile->review_note,
            'created_at' => $profile->created_at?->toIso8601String(),
        ];
    }

    private function paymentData(SupplierPayment $payment): array
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
