<?php

namespace App\Http\Resources\Crm;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Carbon;

/** @mixin \App\Models\Customer */
class CustomerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'farm_id' => (string) $this->farm_id,
            'farm_name' => $this->whenLoaded('farm', fn () => $this->farm?->name),
            'assigned_user_id' => $this->assigned_user_id !== null ? (string) $this->assigned_user_id : null,
            'assignee' => $this->whenLoaded('assignee', fn () => $this->assignee ? [
                'id' => (string) $this->assignee->id,
                'name' => $this->assignee->name,
                'email' => $this->assignee->email,
                'crm_role' => $this->assignee->crm_role,
            ] : null),
            'open_tasks_count' => $this->when(isset($this->open_tasks_count), (int) $this->open_tasks_count),
            'next_task_due_at' => $this->when(isset($this->next_task_due_at) && $this->next_task_due_at !== null, Carbon::parse($this->next_task_due_at)->toIso8601String()),
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'company' => $this->company,
            'address' => $this->address,
            'type' => $this->type,
            'status' => $this->status,
            'notes' => $this->notes,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
