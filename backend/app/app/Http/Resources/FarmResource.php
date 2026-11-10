<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Farm */
class FarmResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'name' => $this->name,
            'location' => $this->location,
            'latitude' => $this->latitude === null ? null : (float) $this->latitude,
            'longitude' => $this->longitude === null ? null : (float) $this->longitude,
            'invite_code' => $this->invite_code,
            'mother_pig_count' => $this->mother_pig_count,
            'piglet_groups' => $this->piglet_groups ?? [],
            'pregnant_pig_count' => $this->pregnant_pig_count,
            'subscription_plan' => $this->subscription_plan,
            'farming_type' => $this->farming_type ?? 'mixed',
            'production_types' => $this->production_types ?? [],
        ];
    }
}
