<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255'],
            'phone' => ['required', 'string', 'max:30'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'role' => ['required', 'string', 'in:buyer,farmOwner,farmManager,farmWorker'],
            // Farm owners name the farm they are creating; managers/workers may join later by requesting a farm.
            'farm_name' => ['required_if:role,farmOwner', 'string', 'max:255'],
            'farming_type' => ['sometimes', 'string', 'in:crops,livestock,mixed'],
            'production_types' => ['sometimes', 'array', 'max:20'],
            'production_types.*' => ['required', 'string', 'max:100'],
            'invite_code' => ['nullable', 'string', 'exists:farms,invite_code'],
            'mother_pig_count' => ['nullable', 'integer', 'min:0'],
            'piglet_groups' => ['nullable', 'array'],
            'piglet_groups.*.count' => ['required', 'integer', 'min:0'],
            'piglet_groups.*.age_months' => ['required', 'integer', 'min:0', 'max:120'],
            'pregnant_pig_count' => ['nullable', 'integer', 'min:0'],
        ];
    }
}
