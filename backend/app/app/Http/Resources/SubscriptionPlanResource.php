<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\SubscriptionPlan */
class SubscriptionPlanResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'code' => $this->code,
            'name' => $this->name,
            'description' => $this->description,
            'amount' => $this->amount,
            'currency' => $this->currency,
            'pig_limit' => $this->pig_limit,
            'active' => $this->active,
        ];
    }
}