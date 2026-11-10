<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Crm\StoreCustomerOrderRequest;
use App\Http\Requests\Crm\UpdateCustomerOrderRequest;
use App\Http\Resources\Crm\CustomerOrderResource;
use App\Models\Customer;
use App\Models\CustomerOrder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class CustomerOrderController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $this->authorizeCrmAccess($request);
        $farmIds = $request->user()->farms()->pluck('farms.id');
        $orders = CustomerOrder::query()
            ->whereIn('farm_id', $farmIds)
            ->with(['farm:id,name', 'customer:id,name'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('farm_id'), fn ($query) => $query->where('farm_id', $request->integer('farm_id')))
            ->when($request->filled('customer_id'), fn ($query) => $query->where('customer_id', $request->integer('customer_id')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = $request->string('search')->toString();
                $query->where(function ($query) use ($term) {
                    $query->where('reference', 'like', "%{$term}%")
                        ->orWhereHas('customer', fn ($customer) => $customer->where('name', 'like', "%{$term}%"));
                });
            })
            ->latest('ordered_at')
            ->paginate(min($request->integer('per_page', 25), 100));

        return response()->json([
            'data' => CustomerOrderResource::collection($orders->getCollection()),
            'meta' => [
                'current_page' => $orders->currentPage(),
                'last_page' => $orders->lastPage(),
                'per_page' => $orders->perPage(),
                'total' => $orders->total(),
            ],
        ]);
    }

    public function store(StoreCustomerOrderRequest $request): JsonResponse
    {
        $this->authorizeCrmWrite($request);
        $data = $request->validated();
        $this->authorizeCustomerFarm($request, (int) $data['farm_id'], (int) $data['customer_id']);
        $order = CustomerOrder::create($data + ['created_by' => $request->user()->id]);
        return response()->json(['data' => new CustomerOrderResource($order->load(['farm:id,name', 'customer:id,name']))], 201);
    }

    public function show(Request $request, CustomerOrder $order): JsonResponse
    {
        $this->authorizeCrmAccess($request);
        $this->authorizeFarm($request, $order->farm_id);
        return response()->json(['data' => new CustomerOrderResource($order->load(['farm:id,name', 'customer:id,name']))]);
    }

    public function update(UpdateCustomerOrderRequest $request, CustomerOrder $order): JsonResponse
    {
        $this->authorizeCrmWrite($request);
        $this->authorizeFarm($request, $order->farm_id);
        $data = $request->validated();
        $order->fill($data);
        if (($data['status'] ?? null) === 'completed' && ! array_key_exists('completed_at', $data)) {
            $order->completed_at = now()->toDateString();
        }
        $order->updated_by = $request->user()->id;
        $order->save();
        return response()->json(['data' => new CustomerOrderResource($order->load(['farm:id,name', 'customer:id,name']))]);
    }

    private function authorizeCustomerFarm(Request $request, int $farmId, int $customerId): void
    {
        $this->authorizeFarm($request, $farmId);
        if (! Customer::whereKey($customerId)->where('farm_id', $farmId)->exists()) {
            throw ValidationException::withMessages(['customer_id' => ['The customer must belong to the selected farm.']]);
        }
    }

    private function authorizeFarm(Request $request, int $farmId): void
    {
        if (! $request->user()->farms()->whereKey($farmId)->exists()) abort(403, 'You do not have access to this farm.');
    }

    private function authorizeCrmAccess(Request $request): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (! in_array($role, ['admin', 'finance', 'customer_support'], true)) abort(403, 'Only CRM staff can access orders.');
    }

    private function authorizeCrmWrite(Request $request): void
    {
        $this->authorizeCrmAccess($request);
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (! in_array($role, ['admin', 'finance'], true)) abort(403, 'Only admins and Finance can modify orders.');
    }
}
