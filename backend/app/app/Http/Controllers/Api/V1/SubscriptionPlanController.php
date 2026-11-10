<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Crm\StoreSubscriptionPlanRequest;
use App\Http\Requests\Crm\UpdateSubscriptionPlanRequest;
use App\Http\Resources\SubscriptionPlanResource;
use App\Models\SubscriptionPlan;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SubscriptionPlanController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $this->authorizePlanAccess($request);
        $plans = SubscriptionPlan::query()
            ->when(! $this->isCrmManager($request), fn ($query) => $query->where('active', true))
            ->orderBy('amount')->get();

        return response()->json(['data' => SubscriptionPlanResource::collection($plans)]);
    }

    public function store(StoreSubscriptionPlanRequest $request): JsonResponse
    {
        $this->authorizePlanManagement($request);
        $plan = SubscriptionPlan::create([...$request->validated(), 'currency' => strtoupper($request->string('currency')->toString())]);
        return response()->json(['data' => new SubscriptionPlanResource($plan)], 201);
    }

    public function update(UpdateSubscriptionPlanRequest $request, SubscriptionPlan $subscriptionPlan): JsonResponse
    {
        $this->authorizePlanManagement($request);
        $data = $request->validated();
        if (isset($data['currency'])) $data['currency'] = strtoupper($data['currency']);
        $subscriptionPlan->update($data);
        return response()->json(['data' => new SubscriptionPlanResource($subscriptionPlan->fresh())]);
    }

    public function destroy(Request $request, SubscriptionPlan $subscriptionPlan): JsonResponse
    {
        $this->authorizePlanManagement($request);
        $subscriptionPlan->update(['active' => false]);
        return response()->json(null, 204);
    }

    private function authorizePlanAccess(Request $request): void
    {
        if (! $this->canViewPlans($request)) {
            abort(403, 'Only farm owners and CRM admin/finance staff can view subscription plans.');
        }
    }

    private function authorizePlanManagement(Request $request): void
    {
        if (! $this->canManagePlans($request)) {
            abort(403, 'Only farm owners and CRM admin/finance staff can manage subscription plans.');
        }
    }

    private function isCrmManager(Request $request): bool
    {
        return in_array($request->user()->crm_role, ['admin', 'finance'], true);
    }

    private function canViewPlans(Request $request): bool
    {
        $user = $request->user();

        return $user->role === 'farmOwner'
            || in_array($user->crm_role, ['admin', 'finance'], true);
    }

    private function canManagePlans(Request $request): bool
    {
        $user = $request->user();

        return $user->role === 'farmOwner'
            || in_array($user->crm_role, ['admin', 'finance'], true);
    }
}