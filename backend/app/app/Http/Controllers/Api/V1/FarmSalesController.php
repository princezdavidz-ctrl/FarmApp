<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\StoreFarmBuyerRequest;
use App\Http\Requests\Farm\StoreFarmSaleRequest;
use App\Http\Requests\Farm\UpdateFarmBuyerRequest;
use App\Http\Requests\Farm\UpdateFarmSaleRequest;
use App\Http\Resources\Crm\CustomerOrderResource;
use App\Http\Resources\Crm\CustomerResource;
use App\Models\Customer;
use App\Models\CustomerOrder;
use App\Models\Farm;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class FarmSalesController extends Controller
{
    public function buyers(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeSales($request, $farm);
        $buyers = $farm->customers()
            ->where('type', 'buyer')
            ->with('assignee:id,name,email')
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = $request->string('search')->toString();
                $query->where(fn ($buyers) => $buyers->where('name', 'like', "%{$term}%")
                    ->orWhere('email', 'like', "%{$term}%")
                    ->orWhere('phone', 'like', "%{$term}%")
                    ->orWhere('company', 'like', "%{$term}%"));
            })
            ->orderBy('name')
            ->limit(250)
            ->get();

        return response()->json(['data' => CustomerResource::collection($buyers)]);
    }

    public function storeBuyer(StoreFarmBuyerRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeSales($request, $farm, write: true);
        $buyer = $farm->customers()->create($request->validated() + [
            'type' => 'buyer',
            'created_by' => $request->user()->id,
        ]);

        return response()->json(['data' => new CustomerResource($buyer)], 201);
    }

    public function updateBuyer(UpdateFarmBuyerRequest $request, Farm $farm, Customer $buyer): JsonResponse
    {
        $this->authorizeSales($request, $farm, write: true);
        abort_unless((int) $buyer->farm_id === (int) $farm->id && $buyer->type === 'buyer', 404);
        $buyer->update($request->validated());

        return response()->json(['data' => new CustomerResource($buyer->fresh())]);
    }

    public function sales(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeSales($request, $farm);
        $sales = $farm->customerOrders()
            ->with('customer:id,name,email,phone,company')
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = $request->string('search')->toString();
                $query->where(fn ($sales) => $sales->where('reference', 'like', "%{$term}%")
                    ->orWhereHas('customer', fn ($buyer) => $buyer->where('name', 'like', "%{$term}%")));
            })
            ->latest('ordered_at')
            ->limit(250)
            ->get();

        return response()->json(['data' => CustomerOrderResource::collection($sales)]);
    }

    public function storeSale(StoreFarmSaleRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeSales($request, $farm, write: true);
        $data = $request->validated();
        $buyer = $farm->customers()->whereKey($data['customer_id'])->where('type', 'buyer')->first();
        if ($buyer === null) {
            throw ValidationException::withMessages(['customer_id' => ['Choose a buyer from this farm.']]);
        }
        if ($farm->customerOrders()->where('reference', $data['reference'])->exists()) {
            throw ValidationException::withMessages(['reference' => ['This sale reference is already used in this farm.']]);
        }

        if (! empty($data['items'])) {
            $data['total_amount'] = round(collect($data['items'])->sum(
                fn (array $item) => (float) ($item['quantity'] ?? 0) * (float) ($item['unit_price'] ?? 0),
            ), 2);
        }
        $sale = $farm->customerOrders()->create($data + ['created_by' => $request->user()->id]);

        return response()->json(['data' => new CustomerOrderResource($sale->load('customer:id,name,email,phone,company'))], 201);
    }

    public function updateSale(UpdateFarmSaleRequest $request, Farm $farm, CustomerOrder $sale): JsonResponse
    {
        $this->authorizeSales($request, $farm, write: true);
        abort_unless((int) $sale->farm_id === (int) $farm->id, 404);
        $data = $request->validated();
        $sale->fill($data);
        if (($data['status'] ?? null) === 'completed' && ! array_key_exists('completed_at', $data)) {
            $sale->completed_at = now()->toDateString();
        } elseif (($data['status'] ?? null) !== 'completed' && array_key_exists('status', $data)) {
            $sale->completed_at = null;
        }
        $sale->updated_by = $request->user()->id;
        $sale->save();

        return response()->json(['data' => new CustomerOrderResource($sale->fresh()->load('customer:id,name,email,phone,company'))]);
    }

    private function authorizeSales(Request $request, Farm $farm, bool $write = false): void
    {
        $user = $request->user();
        $membership = $user->farms()->where('farms.id', $farm->id)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');
        abort_if($user->crm_closed_at !== null, 403, 'This CRM account is inactive.');

        if ($user->role === 'farmOwner') return;

        $crmRole = $user->crm_role;
        if (in_array($crmRole, ['admin', 'finance', 'customer_support'], true)) {
            if ($write && ! in_array($crmRole, ['admin', 'finance'], true)) {
                abort(403, 'This CRM role cannot change sales records.');
            }
            return;
        }

        $permissions = $membership->pivot->permissions === null
            ? $this->defaultPermissions($user->role)
            : json_decode($membership->pivot->permissions, true);
        $canManage = in_array('manageSales', $permissions ?? [], true);
        $canView = $canManage || in_array('viewSales', $permissions ?? [], true);
        abort_unless($write ? $canManage : $canView, 403, $write
            ? 'You do not have permission to manage farm sales.'
            : 'You do not have permission to view farm sales.');
    }

    private function defaultPermissions(string $role): array
    {
        return match ($role) {
            'farmManager', 'salesMarketing' => ['viewSales', 'manageSales'],
            'accountant' => ['viewSales'],
            default => [],
        };
    }
}
