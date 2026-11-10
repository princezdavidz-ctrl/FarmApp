<?php

namespace App\Http\Requests\Crm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCrmMemberRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        return [
            'crm_role' => ['sometimes', Rule::in(['finance', 'customer_support'])],
            'closed' => ['sometimes', 'boolean'],
        ];
    }
}
