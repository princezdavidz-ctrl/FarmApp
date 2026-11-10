<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/** @mixin \App\Models\User */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'avatar_url' => $this->avatar_path === null ? null : Storage::disk('public')->url($this->avatar_path),
            'role' => $this->role,
            'crm_role' => $this->crm_role,
            'is_global_crm_admin' => (bool) $this->is_global_crm_admin,
            'crm_closed_at' => $this->crm_closed_at?->toIso8601String(),
        ];
    }
}
