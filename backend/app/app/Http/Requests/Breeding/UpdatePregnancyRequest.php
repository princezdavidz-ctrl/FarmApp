<?php

namespace App\Http\Requests\Breeding;

use Illuminate\Foundation\Http\FormRequest;

class UpdatePregnancyRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        return [
            'boar_id' => ['nullable', 'integer', 'exists:animals,id'],
            'mating_date' => ['sometimes', 'date'],
            'semen_used' => ['nullable', 'string', 'max:255'],
            'confirmation_date' => ['nullable', 'date'],
            'expected_farrowing_date' => ['sometimes', 'date'],
            'actual_farrowing_date' => ['nullable', 'date'],
            'status' => ['sometimes', 'in:suspected,confirmed,high_risk,farrowed,aborted'],
            'expected_litter_size' => ['nullable', 'integer', 'min:0'],
            'born_alive' => ['nullable', 'integer', 'min:0'],
            'stillborn' => ['nullable', 'integer', 'min:0'],
            'mummified' => ['nullable', 'integer', 'min:0'],
            'weaned' => ['nullable', 'integer', 'min:0'],
            'notes' => ['nullable', 'string', 'max:5000'],
        ];
    }
}