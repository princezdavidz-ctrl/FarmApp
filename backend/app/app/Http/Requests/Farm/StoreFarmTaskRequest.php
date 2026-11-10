<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreFarmTaskRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'assigned_to' => ['nullable', 'integer', 'exists:users,id'],
            'title' => ['required', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:4000'],
            'due_at' => ['nullable', 'date'],
            'priority' => ['sometimes', Rule::in(['low', 'normal', 'high', 'urgent'])],
            'category' => ['sometimes', Rule::in(['feeding', 'health', 'growth', 'sales', 'other'])],
            'status' => ['sometimes', Rule::in(['open', 'completed'])],
        ];
    }
}
