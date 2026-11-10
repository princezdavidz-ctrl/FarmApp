<?php

namespace App\Http\Resources\Inventory;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StockMovementResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $movementLabel = match ($this->type) {
            'stock_in' => 'Stock in',
            'stock_out' => 'Stock out',
            'expired' => 'Expired',
            'adjustment' => 'Adjustment',
            default => ucfirst(str_replace('_', ' ', (string) $this->type)),
        };

        return [
            'id' => $this->id,
            'inventoryItemId' => $this->inventory_item_id,
            'type' => $this->type,
            'quantity' => (float) $this->quantity,
            'movementLabel' => $movementLabel,
            'reference' => $this->reference,
            'notes' => $this->notes,
            'recordedBy' => $this->recorded_by,
            'createdAt' => $this->created_at,
        ];
    }
}
