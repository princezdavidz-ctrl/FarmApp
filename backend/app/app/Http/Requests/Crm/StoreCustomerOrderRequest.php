<?php

namespace App\Http\Requests\Crm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreCustomerOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'farm_id' => ['required', 'integer', Rule::exists('farms', 'id')],
            'customer_id' => ['required', 'integer', Rule::exists('customers', 'id')],
            'reference' => ['required', 'string', 'max:80'],
            'status' => ['sometimes', Rule::in(['pending', 'suspended', 'cancelled', 'ongoing', 'completed'])],
            'items' => ['nullable', 'array'],
            'items.*.name' => ['required_with:items', 'string', 'max:255'],
            'items.*.quantity' => ['nullable', 'numeric', 'min:0'],
            'items.*.unit_price' => ['nullable', 'numeric', 'min:0'],
            'total_amount' => ['required', 'numeric', 'min:0'],
            'currency' => ['required', 'string', 'size:3'],
            'ordered_at' => ['required', 'date'],
            'expected_at' => ['nullable', 'date'],
            'completed_at' => ['nullable', 'date'],
            'notes' => ['nullable', 'string'],
        ];
    }
}
