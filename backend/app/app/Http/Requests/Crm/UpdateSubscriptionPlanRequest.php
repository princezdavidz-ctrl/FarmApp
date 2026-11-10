<?php

namespace App\Http\Requests\Crm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateSubscriptionPlanRequest extends FormRequest
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
            'code' => ['sometimes', 'string', 'max:50', 'alpha_dash', Rule::unique('subscription_plans', 'code')->ignore($this->route('subscription_plan'))],
            'name' => ['sometimes', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:1000'],
            'amount' => ['sometimes', 'numeric', 'min:0'],
            'currency' => ['sometimes', 'string', 'size:3'],
            'pig_limit' => ['nullable', 'integer', 'min:1'],
            'active' => ['sometimes', 'boolean'],
        ];
    }
}