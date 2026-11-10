<?php

namespace App\Http\Resources\Crm;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\CustomerOrder */
class CustomerOrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'farm_id' => (string) $this->farm_id,
            'farm_name' => $this->whenLoaded('farm', fn () => $this->farm?->name),
            'customer_id' => (string) $this->customer_id,
            'customer_name' => $this->whenLoaded('customer', fn () => $this->customer?->name),
            'reference' => $this->reference,
            'status' => $this->status,
            'items' => $this->items ?? [],
            'total_amount' => $this->total_amount,
            'currency' => $this->currency,
            'ordered_at' => $this->ordered_at?->toDateString(),
            'expected_at' => $this->expected_at?->toDateString(),
            'completed_at' => $this->completed_at?->toDateString(),
            'notes' => $this->notes,
            'created_by' => (string) $this->created_by,
            'updated_by' => $this->updated_by !== null ? (string) $this->updated_by : null,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
