<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreFarmBuyerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'company' => ['nullable', 'string', 'max:255'],
            'address' => ['nullable', 'string', 'max:255'],
            'status' => ['sometimes', Rule::in(['new', 'contacted', 'qualified', 'won', 'lost'])],
            'notes' => ['nullable', 'string', 'max:4000'],
        ];
    }
}
