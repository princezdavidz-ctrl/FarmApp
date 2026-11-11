<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreCropCycleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'plot_name' => ['required', 'string', 'max:120'],
            'crop_name' => ['required', 'string', 'max:120'],
            'variety' => ['nullable', 'string', 'max:120'],
            'area_acres' => ['required', 'numeric', 'gt:0', 'max:100000'],
            'planting_date' => ['required', 'date'],
            'expected_harvest_date' => ['nullable', 'date', 'after_or_equal:planting_date'],
            'actual_harvest_date' => ['nullable', 'date', 'after_or_equal:planting_date'],
            'status' => ['sometimes', Rule::in(['planned', 'planted', 'growing', 'harvested', 'failed'])],
            'expected_yield_kg' => ['nullable', 'numeric', 'gte:0'],
            'actual_yield_kg' => ['nullable', 'numeric', 'gte:0'],
            'notes' => ['nullable', 'string', 'max:4000'],
        ];
    }
}
