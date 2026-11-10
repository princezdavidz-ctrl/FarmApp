<?php

namespace App\Http\Requests\Crm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCustomerOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'reference' => ['sometimes', 'string', 'max:80'],
            'status' => ['sometimes', Rule::in(['pending', 'suspended', 'cancelled', 'ongoing', 'completed'])],
            'items' => ['nullable', 'array'],
            'items.*.name' => ['required_with:items', 'string', 'max:255'],
            'items.*.quantity' => ['nullable', 'numeric', 'min:0'],
            'items.*.unit_price' => ['nullable', 'numeric', 'min:0'],
            'total_amount' => ['sometimes', 'numeric', 'min:0'],
            'currency' => ['sometimes', 'string', 'size:3'],
            'ordered_at' => ['sometimes', 'date'],
            'expected_at' => ['nullable', 'date'],
            'completed_at' => ['nullable', 'date'],
            'notes' => ['nullable', 'string'],
        ];
    }
}
