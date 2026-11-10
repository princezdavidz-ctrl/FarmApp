<?php

namespace App\Http\Resources\Crm;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\CustomerInteraction */
class CustomerInteractionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'customer_id' => (string) $this->customer_id,
            'user_id' => $this->user_id !== null ? (string) $this->user_id : null,
            'type' => $this->type,
            'notes' => $this->notes,
            'occurred_at' => $this->occurred_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
