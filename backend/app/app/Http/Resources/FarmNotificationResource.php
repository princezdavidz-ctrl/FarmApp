<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\FarmNotification */
class FarmNotificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'type' => $this->type,
            'title' => $this->title,
            'body' => $this->body,
            'severity' => $this->severity,
            'related_type' => $this->related_type,
            'related_id' => $this->related_id ? (string) $this->related_id : null,
            'action_route' => $this->action_route,
            'read_at' => $this->read_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}