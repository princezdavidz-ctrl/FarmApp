<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;

class StoreFarmJoinRequest extends FormRequest
{
    public function authorize(): bool
    {
        return in_array($this->user()?->role, ['farmManager', 'farmWorker'], true);
    }

    public function rules(): array
    {
        return [
            'invite_code' => ['required', 'string', 'exists:farms,invite_code'],
            'message' => ['nullable', 'string', 'max:1000'],
        ];
    }
}