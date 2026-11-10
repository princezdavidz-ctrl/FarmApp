<?php

namespace App\Http\Requests\Crm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:255'],
            'assigned_user_id' => ['nullable', 'integer', Rule::exists('users', 'id')],
            'email' => ['nullable', 'string', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'company' => ['nullable', 'string', 'max:255'],
            'address' => ['nullable', 'string', 'max:255'],
            'type' => ['sometimes', Rule::in(['lead', 'buyer', 'supplier'])],
            'status' => ['sometimes', Rule::in(['new', 'contacted', 'qualified', 'won', 'lost'])],
            'notes' => ['nullable', 'string'],
        ];
    }
}
