<?php

namespace App\Http\Resources\Farm;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\FarmTask */
class FarmTaskResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'farm_id' => (string) $this->farm_id,
            'assigned_to' => $this->assigned_to !== null ? (string) $this->assigned_to : null,
            'assignee' => $this->whenLoaded('assignee', fn () => $this->assignee ? [
                'id' => (string) $this->assignee->id,
                'name' => $this->assignee->name,
                'email' => $this->assignee->email,
            ] : null),
            'created_by' => (string) $this->created_by,
            'title' => $this->title,
            'notes' => $this->notes,
            'due_at' => $this->due_at?->toIso8601String(),
            'priority' => $this->priority,
            'category' => $this->category,
            'status' => $this->status,
            'completed_at' => $this->completed_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
