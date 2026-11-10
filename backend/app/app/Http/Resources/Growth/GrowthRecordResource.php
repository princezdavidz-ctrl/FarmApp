<?php

namespace App\Http\Resources\Growth;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\GrowthRecord */
class GrowthRecordResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'farm_id' => (string) $this->farm_id,
            'animal_id' => (string) $this->animal_id,
            'pig_id' => (string) $this->animal_id,
            'rfid' => $this->rfid,
            'current_weight' => $this->current_weight,
            'previous_weight' => $this->previous_weight,
            'weight_gain' => $this->weight_gain,
            'daily_gain' => $this->daily_gain,
            'age_in_days' => $this->age_in_days,
            'measurement_date' => $this->measurement_date?->toIso8601String(),
            'recorded_by' => $this->recorded_by,
            'notes' => $this->notes,
            'photo_url' => $this->photo_url,
            'target_weight' => $this->target_weight,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
