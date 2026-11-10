<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;

class StoreFarmRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->role === 'farmOwner';
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'location' => ['nullable', 'string', 'max:255'],
            'farming_type' => ['sometimes', 'string', 'in:crops,livestock,mixed'],
            'production_types' => ['sometimes', 'array', 'max:20'],
            'production_types.*' => ['required', 'string', 'max:100'],
        ];
    }
}