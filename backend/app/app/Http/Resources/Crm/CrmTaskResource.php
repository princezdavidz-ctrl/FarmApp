<?php

namespace App\Http\Resources\Crm;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\CrmTask */
class CrmTaskResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'customer_id' => (string) $this->customer_id,
            'assigned_to' => $this->assigned_to !== null ? (string) $this->assigned_to : null,
            'customer' => $this->whenLoaded('customer', fn () => $this->customer ? [
                'id' => (string) $this->customer->id,
                'name' => $this->customer->name,
                'email' => $this->customer->email,
                'company' => $this->customer->company,
            ] : null),
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
            'status' => $this->status,
            'completed_at' => $this->completed_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
