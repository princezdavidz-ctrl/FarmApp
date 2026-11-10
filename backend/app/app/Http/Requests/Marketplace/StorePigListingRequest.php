<?php

namespace App\Http\Requests\Marketplace;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePigListingRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:120'],
            'animal_id' => ['required', 'integer', 'exists:animals,id'],
            'breed' => ['required', 'string', 'max:100'],
            'age_weeks' => ['nullable', 'integer', 'min:1', 'max:156'],
            'weight_kg' => ['nullable', 'numeric', 'gt:0', 'max:1000'],
            'quantity' => ['required', 'integer', 'min:1', 'max:10000'],
            'price_per_pig' => ['required', 'numeric', 'gt:0', 'max:100000000'],
            'currency' => ['required', 'string', 'size:3'],
            'location' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:4000'],
            'status' => ['sometimes', Rule::in(['available', 'unavailable', 'sold'])],
        ];
    }
}
