<?php

namespace App\Http\Requests\Marketplace;

use Illuminate\Foundation\Http\FormRequest;

class StorePigInquiryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'buyer_name' => ['required', 'string', 'max:120'],
            'phone' => ['required', 'string', 'max:40'],
            'email' => ['nullable', 'email', 'max:255'],
            'quantity' => ['required', 'integer', 'min:1', 'max:10000'],
            'message' => ['nullable', 'string', 'max:2000'],
        ];
    }
}
