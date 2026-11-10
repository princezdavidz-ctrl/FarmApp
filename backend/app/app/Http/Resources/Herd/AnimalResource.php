<?php

namespace App\Http\Resources\Herd;

use Illuminate\Support\Facades\Storage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Animal */
class AnimalResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'farm_id' => (string) $this->farm_id,
            'tag' => $this->tag,
            'name' => $this->name,
            'type' => $this->type,
            'sex' => $this->sex,
            'status' => $this->status,
            'birth_date' => $this->birth_date?->toDateString(),
            'weight_kg' => $this->weight_kg === null ? null : (float) $this->weight_kg,
            'is_pregnant' => (bool) $this->is_pregnant,
            'last_dewormed_at' => $this->last_dewormed_at?->toDateString(),
            'last_vaccinated_at' => $this->last_vaccinated_at?->toDateString(),
            'notes' => $this->notes,
            'image_url' => $this->image_path === null
                ? null
                : Storage::disk('public')->url($this->image_path),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
