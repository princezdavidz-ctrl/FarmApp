<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Crm\StoreCustomerInteractionRequest;
use App\Http\Resources\Crm\CustomerInteractionResource;
use App\Models\Customer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class CustomerInteractionController extends Controller
{
    public function index(Request $request, Customer $customer): JsonResponse
    {
        $this->authorizeCrmAccess($request);
        $this->authorizeFarm($request, $customer->farm_id);

        return response()->json(['data' => CustomerInteractionResource::collection($customer->interactions)]);
    }

    public function store(StoreCustomerInteractionRequest $request, Customer $customer): JsonResponse
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (!in_array($role, ['admin', 'customer_support'], true)) abort(403, 'Only customer support can reply to customers.');
        $this->authorizeFarm($request, $customer->farm_id);

        $interaction = $customer->interactions()->create([
            ...$request->validated(),
            'user_id' => $request->user()->id,
            'occurred_at' => $request->input('occurred_at') ?? now(),
        ]);

        return response()->json(['data' => new CustomerInteractionResource($interaction)], 201);
    }

    private function authorizeFarm(Request $request, int $farmId): void
    {
        $belongsToFarm = $request->user()->farms()->where('farms.id', $farmId)->exists();

        if (! $belongsToFarm) {
            throw ValidationException::withMessages(['farm_id' => ['You do not have access to this farm.']]);
        }
    }

    private function authorizeCrmAccess(Request $request): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (! in_array($role, ['admin', 'finance', 'customer_support'], true)) {
            abort(403, 'Only CRM staff can access customer interactions.');
        }
    }
}
