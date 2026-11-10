<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;

class StoreMpesaPaymentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->role === 'farmOwner';
    }

    public function rules(): array
    {
        return [
            'plan' => ['required', 'string', 'exists:subscription_plans,code'],
            'phone' => ['nullable', 'string', 'regex:/^(\+?254|0)[0-9\s-]{9,}$/'],
        ];
    }

    public function normalizedPhone(): ?string
    {
        $phone = $this->input('phone');
        if (blank($phone)) {
            return null;
        }

        $digits = preg_replace('/\D+/', '', $phone);
        if (blank($digits)) {
            return null;
        }

        if (str_starts_with($digits, '0')) {
            $digits = '254'.substr($digits, 1);
        }

        return preg_match('/^254[17]\d{8}$/', $digits) ? $digits : null;
    }
}