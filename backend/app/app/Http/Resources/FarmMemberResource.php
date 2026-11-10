<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\User */
class FarmMemberResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'role' => $this->role,
            'crm_role' => $this->crm_role,
            // Null means the member uses the default permission set for their role.
            'permissions' => $this->pivot?->permissions === null ? null : json_decode($this->pivot->permissions, true),
        ];
    }
}
