<?php

namespace App\Http\Requests\Herd;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateAnimalRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'tag' => ['sometimes', 'string', 'max:50'],
            'name' => ['sometimes', 'nullable', 'string', 'max:100'],
            'status' => ['sometimes', Rule::in(['active', 'sold', 'deceased'])],
            'sex' => ['sometimes', Rule::in(['male', 'female', 'unknown'])],
            'birth_date' => ['nullable', 'date'],
            'weight_kg' => ['sometimes', 'nullable', 'numeric', 'min:0', 'max:999999.99'],
            'is_pregnant' => ['sometimes', 'boolean'],
            'last_dewormed_at' => ['sometimes', 'nullable', 'date', 'before_or_equal:today'],
            'last_vaccinated_at' => ['sometimes', 'nullable', 'date', 'before_or_equal:today'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'image' => ['nullable', 'image', 'max:5120'],
        ];
    }
}
