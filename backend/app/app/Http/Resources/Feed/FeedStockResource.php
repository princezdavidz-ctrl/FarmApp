<?php

namespace App\Http\Resources\Feed;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\FeedStock */
class FeedStockResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'farm_id' => (string) $this->farm_id,
            'name' => $this->name,
            'quantity' => (float) $this->quantity,
            'unit' => $this->unit,
            'unit_cost' => $this->unit_cost === null ? null : (float) $this->unit_cost,
            'location' => $this->location,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
