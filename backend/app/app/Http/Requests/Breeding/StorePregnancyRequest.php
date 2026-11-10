<?php

namespace App\Http\Requests\Breeding;

use Illuminate\Foundation\Http\FormRequest;

class StorePregnancyRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        return [
            'sow_id' => ['required', 'integer', 'exists:animals,id'],
            'boar_id' => ['nullable', 'integer', 'exists:animals,id'],
            'mating_date' => ['required', 'date'],
            'semen_used' => ['nullable', 'string', 'max:255'],
            'confirmation_date' => ['nullable', 'date', 'after_or_equal:mating_date'],
            'expected_farrowing_date' => ['nullable', 'date', 'after:mating_date'],
            'status' => ['sometimes', 'in:suspected,confirmed,high_risk,farrowed,aborted'],
            'expected_litter_size' => ['nullable', 'integer', 'min:0'],
            'notes' => ['nullable', 'string', 'max:5000'],
        ];
    }
}