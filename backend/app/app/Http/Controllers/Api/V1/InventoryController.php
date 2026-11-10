<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Inventory\RecordStockMovementRequest;
use App\Http\Requests\Inventory\StoreInventoryItemRequest;
use App\Http\Requests\Inventory\UpdateInventoryItemRequest;
use App\Http\Resources\Inventory\InventoryItemResource;
use App\Http\Resources\Inventory\StockMovementResource;
use App\Models\Farm;
use App\Models\InventoryItem;
use App\Models\InventoryMovement;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InventoryController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeInventoryAccess($request, $farm);

        $items = $farm->inventoryItems()
            ->latest()
            ->paginate(50);

        $totalItems = $farm->inventoryItems()->count();
        $lowStockItems = $farm->inventoryItems()
            ->whereRaw('quantity <= minimum_level')
            ->count();
        $expiringItems = $farm->inventoryItems()
            ->whereNotNull('expiry_date')
            ->where('expiry_date', '<=', now()->addDays(30))
            ->count();
        $inventoryValue = $farm->inventoryItems()
            ->selectRaw('SUM(quantity * cost_price) as total')
            ->value('total') ?? 0;

        return response()->json([
            'data' => InventoryItemResource::collection($items),
            'pagination' => [
                'total' => $items->total(),
                'per_page' => $items->perPage(),
                'current_page' => $items->currentPage(),
                'last_page' => $items->lastPage(),
            ],
            'summary' => [
                'totalItems' => $totalItems,
                'lowStockItems' => $lowStockItems,
                'expiringItems' => $expiringItems,
                'inventoryValue' => (float) $inventoryValue,
            ],
        ]);
    }

    public function store(StoreInventoryItemRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeInventoryAccess($request, $farm);

        $item = DB::transaction(function () use ($request, $farm) {
            $item = $farm->inventoryItems()->create(
                $request->validated() + ['created_by' => $request->user()->id]
            );

            // Record initial stock-in movement
            $farm->inventoryItems()->find($item->id)->movements()->create([
                'type' => 'stock_in',
                'quantity' => $request->validated('quantity'),
                'reference' => 'Initial stock',
                'recorded_by' => $request->user()->id,
            ]);

            return $item;
        });

        return response()->json(['data' => new InventoryItemResource($item)], 201);
    }

    public function show(Request $request, Farm $farm, InventoryItem $item): JsonResponse
    {
        $this->authorizeInventoryAccess($request, $farm);
        $this->authorizeItemBelongsToFarm($item, $farm);

        return response()->json([
            'item' => new InventoryItemResource($item),
            'movements' => StockMovementResource::collection($item->movements()->latest()->limit(20)->get()),
        ]);
    }

    public function update(UpdateInventoryItemRequest $request, Farm $farm, InventoryItem $item): JsonResponse
    {
        $this->authorizeInventoryAccess($request, $farm);
        $this->authorizeItemBelongsToFarm($item, $farm);

        $item->update($request->validated());

        return response()->json(['data' => new InventoryItemResource($item)]);
    }

    public function destroy(Request $request, Farm $farm, InventoryItem $item): JsonResponse
    {
        $this->authorizeInventoryAccess($request, $farm);
        $this->authorizeItemBelongsToFarm($item, $farm);

        $item->delete();

        return response()->json(null, 204);
    }

    public function recordMovement(RecordStockMovementRequest $request, Farm $farm, InventoryItem $item): JsonResponse
    {
        $this->authorizeInventoryAccess($request, $farm);
        $this->authorizeItemBelongsToFarm($item, $farm);

        $movement = DB::transaction(function () use ($request, $item) {
            $data = $request->validated();
            
            // Record the movement
            $movement = $item->movements()->create(
                $data + ['recorded_by' => request()->user()->id]
            );

            // Update quantity based on movement type
            $quantity = (float) $item->quantity;
            $movementQty = (float) $data['quantity'];

            match ($data['type']) {
                'stock_in' => $quantity += $movementQty,
                'stock_out', 'expired' => $quantity -= $movementQty,
                'adjustment' => $quantity = $movementQty,
                default => $quantity
            };

            $item->update(['quantity' => max(0, $quantity)]);

            return $movement->load('inventoryItem');
        });

        return response()->json(['data' => new StockMovementResource($movement)], 201);
    }

    public function getMovements(Request $request, Farm $farm, InventoryItem $item): JsonResponse
    {
        $this->authorizeInventoryAccess($request, $farm);
        $this->authorizeItemBelongsToFarm($item, $farm);

        $movements = $item->movements()
            ->latest()
            ->paginate(50);

        return response()->json([
            'data' => StockMovementResource::collection($movements),
            'pagination' => [
                'total' => $movements->total(),
                'per_page' => $movements->perPage(),
                'current_page' => $movements->currentPage(),
                'last_page' => $movements->lastPage(),
            ],
        ]);
    }

    public function getAlerts(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeInventoryAccess($request, $farm);

        $lowStockItems = $farm->inventoryItems()
            ->whereRaw('quantity <= minimum_level')
            ->get();

        $expiringItems = $farm->inventoryItems()
            ->whereNotNull('expiry_date')
            ->where('expiry_date', '<=', now()->addDays(30))
            ->where('expiry_date', '>', now())
            ->get();

        $expiredItems = $farm->inventoryItems()
            ->whereNotNull('expiry_date')
            ->where('expiry_date', '<=', now())
            ->get();

        return response()->json([
            'lowStock' => InventoryItemResource::collection($lowStockItems),
            'expiring' => InventoryItemResource::collection($expiringItems),
            'expired' => InventoryItemResource::collection($expiredItems),
        ]);
    }

    public function getByCategory(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeInventoryAccess($request, $farm);

        $category = $request->query('category');
        if (!in_array($category, ['Feed', 'Medicine', 'Vaccines', 'Equipment', 'Cleaning', 'RFID', 'Other'])) {
            return response()->json(['message' => 'Invalid category'], 422);
        }

        $items = $farm->inventoryItems()
            ->where('category', $category)
            ->latest()
            ->get();

        return response()->json([
            'category' => $category,
            'items' => InventoryItemResource::collection($items),
            'count' => $items->count(),
        ]);
    }

    private function authorizeInventoryAccess(Request $request, Farm $farm): void
    {
        $user = $request->user();
        $membership = $user->farms()->where('farms.id', $farm->id)->first();
        if ($membership === null) abort(403, 'You do not have access to this farm.');
        if ($user->role === 'farmOwner') return;
        $permissions = $membership->pivot->permissions === null
            ? match ($user->role) {
                'farmManager' => ['manageInventory'],
                'farmWorker' => ['viewInventory'],
                default => [],
            }
            : json_decode($membership->pivot->permissions, true);
        if (!in_array('manageInventory', $permissions ?? [], true) && 
            !in_array('viewInventory', $permissions ?? [], true)) {
            abort(403, 'You do not have permission to access inventory.');
        }
    }

    private function authorizeItemBelongsToFarm(InventoryItem $item, Farm $farm): void
    {
        if ($item->farm_id !== $farm->id) {
            abort(404, 'Inventory item not found');
        }
    }
}
