<?php

namespace App\Http\Requests\Crm;

use Illuminate\Foundation\Http\FormRequest;

class StoreSubscriptionPlanRequest extends FormRequest
{
    public function authorize(): bool
    {
        $user = $this->user();

        return $user !== null
            && ($user->role === 'farmOwner' || in_array($user->crm_role, ['admin', 'finance'], true));
    }

    public function rules(): array
    {
        return [
            'code' => ['required', 'string', 'max:50', 'alpha_dash', 'unique:subscription_plans,code'],
            'name' => ['required', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:1000'],
            'amount' => ['required', 'numeric', 'min:0'],
            'currency' => ['required', 'string', 'size:3'],
            'pig_limit' => ['nullable', 'integer', 'min:1'],
            'active' => ['sometimes', 'boolean'],
        ];
    }
}