<?php

namespace App\Http\Requests\Crm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCrmTaskRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'assigned_to' => ['sometimes', 'nullable', 'integer', Rule::exists('users', 'id')],
            'title' => ['sometimes', 'string', 'max:255'],
            'notes' => ['sometimes', 'nullable', 'string'],
            'due_at' => ['sometimes', 'nullable', 'date'],
            'priority' => ['sometimes', Rule::in(['low', 'normal', 'high', 'urgent'])],
            'status' => ['sometimes', Rule::in(['open', 'completed', 'cancelled'])],
        ];
    }
}
