<?php

namespace App\Http\Resources\Feed;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\FeedUsage */
class FeedUsageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'farm_id' => (string) $this->farm_id,
            'feed_stock_id' => $this->feed_stock_id === null ? null : (string) $this->feed_stock_id,
            'feed_name' => $this->stock?->name,
            'quantity' => (float) $this->quantity,
            'unit' => $this->unit,
            'used_at' => $this->used_at?->toIso8601String(),
            'notes' => $this->notes,
        ];
    }
}
