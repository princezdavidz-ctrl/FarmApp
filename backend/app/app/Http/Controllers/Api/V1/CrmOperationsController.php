<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\Herd\AnimalResource;
use App\Models\Farm;
use App\Models\FeedStock;
use App\Models\HealthRecord;
use App\Models\InventoryMovement;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CrmOperationsController extends Controller
{
    public function feedOrders(Request $request): JsonResponse
    {
        $farmIds = $this->accessibleFarmIds($request);
        $orders = FeedStock::query()
            ->with(['farm:id,name', 'creator:id,name'])
            ->whereIn('farm_id', $farmIds)
            ->latest()
            ->paginate($this->pageSize($request));

        return response()->json([
            'data' => $orders->getCollection()->map(fn (FeedStock $stock): array => [
                'id' => (string) $stock->id,
                'farm_id' => (string) $stock->farm_id,
                'farm_name' => $stock->farm?->name,
                'feed' => $stock->name,
                'quantity' => (float) $stock->quantity,
                'unit' => $stock->unit,
                'unit_cost' => $stock->unit_cost === null ? null : (float) $stock->unit_cost,
                'location' => $stock->location,
                'recorded_by' => $stock->creator?->name,
                'created_at' => $stock->created_at?->toIso8601String(),
            ])->values(),
            'meta' => $this->paginationMeta($orders),
        ]);
    }

    public function medicineOrders(Request $request): JsonResponse
    {
        $farmIds = $this->accessibleFarmIds($request);
        $orders = InventoryMovement::query()
            ->with([
                'inventoryItem.farm:id,name',
                'inventoryItem:id,farm_id,name,category,unit,cost_price',
                'recordedBy:id,name',
            ])
            ->where('type', 'stock_in')
            ->whereHas('inventoryItem', fn ($query) => $query
                ->whereIn('farm_id', $farmIds)
                ->where('category', 'Medicine'))
            ->latest()
            ->paginate($this->pageSize($request));

        return response()->json([
            'data' => $orders->getCollection()->map(function (InventoryMovement $movement): array {
                $item = $movement->inventoryItem;

                return [
                    'id' => (string) $movement->id,
                    'farm_id' => (string) $item->farm_id,
                    'farm_name' => $item->farm?->name,
                    'medicine' => $item->name,
                    'quantity' => (float) $movement->quantity,
                    'unit' => $item->unit,
                    'unit_cost' => (float) $item->cost_price,
                    'reference' => $movement->reference,
                    'recorded_by' => $movement->recordedBy?->name,
                    'created_at' => $movement->created_at?->toIso8601String(),
                ];
            })->values(),
            'meta' => $this->paginationMeta($orders),
        ]);
    }

    public function emergencies(Request $request): JsonResponse
    {
        $farmIds = $this->accessibleFarmIds($request);
        $reports = HealthRecord::query()
            ->with([
                'farm:id,name',
                'animal:id,tag',
                'creator:id,name',
            ])
            ->whereIn('farm_id', $farmIds)
            ->where(fn ($query) => $query
                ->whereIn('status', ['critical', 'recovering', 'deceased'])
                ->orWhere('type', 'mortality'))
            ->latest()
            ->paginate($this->pageSize($request));

        return response()->json([
            'data' => $reports->getCollection()->map(fn (HealthRecord $record): array => [
                'id' => (string) $record->id,
                'farm_id' => (string) $record->farm_id,
                'farm_name' => $record->farm?->name,
                'pig_tag' => $record->animal?->tag,
                'type' => $record->type,
                'status' => $record->status,
                'diagnosis' => $record->diagnosis,
                'symptoms' => $record->symptoms ?? [],
                'medication' => $record->medication,
                'notes' => $record->notes,
                'reported_by' => $record->creator?->name,
                'reported_at' => $record->created_at?->toIso8601String(),
            ])->values(),
            'meta' => $this->paginationMeta($reports),
        ]);
    }

    public function herd(Request $request): JsonResponse
    {
        $data = $request->validate([
            'search' => ['required', 'string', 'min:2', 'max:120'],
        ]);
        $farmIds = $this->accessibleHerdFarmIds($request);
        $term = trim($data['search']);

        $farms = Farm::query()
            ->whereIn('id', $farmIds)
            ->where('name', 'like', "%{$term}%")
            ->with(['animals' => fn ($query) => $query->latest()])
            ->orderBy('name')
            ->limit(50)
            ->get(['id', 'name', 'location']);

        return response()->json([
            'data' => $farms->map(fn (Farm $farm): array => [
                'id' => (string) $farm->id,
                'name' => $farm->name,
                'location' => $farm->location,
                'animals' => $farm->animals
                    ->map(fn ($animal): array => (new AnimalResource($animal))->resolve($request))
                    ->values(),
            ])->values(),
        ]);
    }

    private function accessibleFarmIds(Request $request)
    {
        $user = $request->user();
        $this->authorizeCrmAccess($request);

        return (bool) $user->is_global_crm_admin
            ? Farm::query()->select('id')
            : $user->farms()->select('farms.id');
    }

    private function accessibleHerdFarmIds(Request $request)
    {
        $user = $request->user();
        if ($user->is_global_crm_admin) {
            return Farm::query()->select('id');
        }

        $crmRole = $user->crm_role ?? ($user->role === 'farmOwner' ? 'admin' : null);
        if (in_array($crmRole, ['admin', 'finance', 'customer_support'], true)) {
            return $user->farms()->select('farms.id');
        }

        abort_unless(in_array($user->role, ['farmOwner', 'farmManager', 'farmWorker'], true), 403);

        $farmIds = $user->farms()
            ->get(['farms.id', 'farm_user.permissions'])
            ->filter(function (Farm $farm) use ($user): bool {
                if ($user->role === 'farmOwner' || $farm->pivot->permissions === null) {
                    return true;
                }

                $permissions = is_array($farm->pivot->permissions)
                    ? $farm->pivot->permissions
                    : json_decode($farm->pivot->permissions, true);

                return in_array('manageHerd', $permissions ?? [], true);
            })
            ->modelKeys();

        return $farmIds;
    }

    private function authorizeCrmAccess(Request $request): void
    {
        $user = $request->user();
        $role = $user->crm_role ?? ($user->role === 'farmOwner' ? 'admin' : null);
        abort_unless(
            $user->is_global_crm_admin || in_array($role, ['admin', 'finance', 'customer_support'], true),
            403,
            'Only CRM staff can access farm operations records.',
        );
    }

    private function pageSize(Request $request): int
    {
        return min(max($request->integer('per_page', 50), 1), 100);
    }

    private function paginationMeta($paginator): array
    {
        return [
            'current_page' => $paginator->currentPage(),
            'last_page' => $paginator->lastPage(),
            'per_page' => $paginator->perPage(),
            'total' => $paginator->total(),
        ];
    }
}
