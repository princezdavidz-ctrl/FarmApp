<?php

namespace App\Http\Requests\Crm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreCustomerInteractionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'type' => ['required', Rule::in(['call', 'email', 'visit', 'meeting', 'note', 'message'])],
            'notes' => ['nullable', 'string'],
            'occurred_at' => ['nullable', 'date'],
        ];
    }
}
