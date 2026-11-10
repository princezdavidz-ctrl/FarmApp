<?php

namespace App\Http\Resources\Inventory;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InventoryItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $stockStatus = $this->isExpired()
            ? 'expired'
            : ($this->isLowStock() ? 'low_stock' : 'in_stock');

        return [
            'id' => $this->id,
            'farmId' => $this->farm_id,
            'name' => $this->name,
            'category' => $this->category,
            'sku' => $this->sku,
            'barcode' => $this->barcode,
            'quantity' => (float) $this->quantity,
            'unit' => $this->unit,
            'minimumLevel' => (float) $this->minimum_level,
            'costPrice' => (float) $this->cost_price,
            'supplier' => $this->supplier,
            'expiryDate' => $this->expiry_date?->format('Y-m-d'),
            'storageLocation' => $this->storage_location,
            'notes' => $this->notes,
            'createdBy' => $this->created_by,
            'createdAt' => $this->created_at,
            'updatedAt' => $this->updated_at,
            'isLowStock' => $this->isLowStock(),
            'isExpired' => $this->isExpired(),
            'isExpiringSoon' => $this->isExpiringSoon(),
            'totalValue' => $this->inventoryValue(),
            'stockStatus' => $stockStatus,
            'inventoryValue' => $this->inventoryValue(),
        ];
    }
}
