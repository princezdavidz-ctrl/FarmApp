<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCropCycleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'plot_name' => ['sometimes', 'required', 'string', 'max:120'],
            'crop_name' => ['sometimes', 'required', 'string', 'max:120'],
            'variety' => ['sometimes', 'nullable', 'string', 'max:120'],
            'area_acres' => ['sometimes', 'required', 'numeric', 'gt:0', 'max:100000'],
            'planting_date' => ['sometimes', 'required', 'date'],
            'expected_harvest_date' => ['sometimes', 'nullable', 'date'],
            'actual_harvest_date' => ['sometimes', 'nullable', 'date'],
            'status' => ['sometimes', Rule::in(['planned', 'planted', 'growing', 'harvested', 'failed'])],
            'expected_yield_kg' => ['sometimes', 'nullable', 'numeric', 'gte:0'],
            'actual_yield_kg' => ['sometimes', 'nullable', 'numeric', 'gte:0'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:4000'],
        ];
    }
}
