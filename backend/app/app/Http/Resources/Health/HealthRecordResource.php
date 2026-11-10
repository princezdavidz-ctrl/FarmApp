<?php

namespace App\Http\Resources\Health;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\HealthRecord */
class HealthRecordResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'farm_id' => (string) $this->farm_id,
            'animal_id' => (string) $this->animal_id,
            'pig_id' => $this->animal?->tag ?? (string) $this->animal_id,
            'type' => $this->type,
            'status' => $this->status,
            'rfid' => $this->rfid,
            'symptoms' => $this->symptoms ?? [],
            'diagnosis' => $this->diagnosis,
            'medication' => $this->medication,
            'dosage' => $this->dosage,
            'veterinarian' => $this->veterinarian,
            'visit_date' => $this->visit_date?->toIso8601String(),
            'next_checkup_date' => $this->next_checkup_date?->toIso8601String(),
            'notes' => $this->notes,
            'attachment_urls' => $this->attachment_urls ?? [],
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
