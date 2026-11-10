<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateFarmTaskRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'assigned_to' => ['sometimes', 'nullable', 'integer', 'exists:users,id'],
            'title' => ['sometimes', 'required', 'string', 'max:255'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:4000'],
            'due_at' => ['sometimes', 'nullable', 'date'],
            'priority' => ['sometimes', Rule::in(['low', 'normal', 'high', 'urgent'])],
            'category' => ['sometimes', Rule::in(['feeding', 'health', 'growth', 'sales', 'other'])],
            'status' => ['sometimes', Rule::in(['open', 'completed'])],
        ];
    }
}
