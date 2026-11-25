<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;

class StoreSoilTestRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'sampled_at' => ['required', 'date', 'before_or_equal:today'],
            'laboratory_name' => ['nullable', 'string', 'max:160'],
            'ph' => ['nullable', 'numeric', 'between:0,14'],
            'nitrogen_ppm' => ['nullable', 'numeric', 'min:0', 'max:100000'],
            'phosphorus_ppm' => ['nullable', 'numeric', 'min:0', 'max:100000'],
            'potassium_ppm' => ['nullable', 'numeric', 'min:0', 'max:100000'],
            'organic_matter_percent' => ['nullable', 'numeric', 'between:0,100'],
            'moisture_percent' => ['nullable', 'numeric', 'between:0,100'],
            'recommendations' => ['nullable', 'string', 'max:4000'],
            'notes' => ['nullable', 'string', 'max:4000'],
        ];
    }
}
