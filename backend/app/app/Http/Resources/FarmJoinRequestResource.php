<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\FarmJoinRequest */
class FarmJoinRequestResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'farmId' => (string) $this->farm_id,
            'farmName' => $this->farm?->name,
            'userId' => (string) $this->user_id,
            'userName' => $this->user?->name,
            'userEmail' => $this->user?->email,
            'requestedRole' => $this->requested_role,
            'status' => $this->status,
            'message' => $this->message,
            'createdAt' => $this->created_at?->toIso8601String(),
        ];
    }
}