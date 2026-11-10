<?php

namespace App\Http\Resources\Breeding;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Pregnancy */
class PregnancyResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'farm_id' => (string) $this->farm_id,
            'sow_id' => (string) $this->sow_id,
            'sow' => $this->whenLoaded('sow', fn () => [
                'id' => (string) $this->sow->id,
                'tag' => $this->sow->tag,
            ]),
            'boar_id' => $this->boar_id ? (string) $this->boar_id : null,
            'boar' => $this->whenLoaded('boar', fn () => $this->boar ? [
                'id' => (string) $this->boar->id,
                'tag' => $this->boar->tag,
            ] : null),
            'mating_date' => $this->mating_date?->toDateString(),
            'semen_used' => $this->semen_used,
            'confirmation_date' => $this->confirmation_date?->toDateString(),
            'expected_farrowing_date' => $this->expected_farrowing_date?->toDateString(),
            'actual_farrowing_date' => $this->actual_farrowing_date?->toDateString(),
            'status' => $this->status,
            'expected_litter_size' => $this->expected_litter_size,
            'born_alive' => $this->born_alive,
            'stillborn' => $this->stillborn,
            'mummified' => $this->mummified,
            'weaned' => $this->weaned,
            'notes' => $this->notes,
            'days_until_farrowing' => $this->expected_farrowing_date
                ? now()->startOfDay()->diffInDays($this->expected_farrowing_date, false)
                : null,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}