<?php

namespace App\Http\Requests\Crm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreCrmTaskRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'assigned_to' => ['nullable', 'integer', Rule::exists('users', 'id')],
            'title' => ['required', 'string', 'max:255'],
            'notes' => ['nullable', 'string'],
            'due_at' => ['nullable', 'date'],
            'priority' => ['sometimes', Rule::in(['low', 'normal', 'high', 'urgent'])],
            'status' => ['sometimes', Rule::in(['open', 'completed', 'cancelled'])],
        ];
    }
}
