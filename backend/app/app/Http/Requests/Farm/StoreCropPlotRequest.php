<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreCropPlotRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $farmId = $this->route('farm')?->id;

        return [
            'name' => [
                'required', 'string', 'max:120',
                Rule::unique('crop_plots', 'name')->where('farm_id', $farmId),
            ],
            'area_acres' => ['required', 'numeric', 'gt:0', 'max:100000'],
            'soil_type' => ['nullable', 'string', 'max:80'],
            'irrigation_source' => ['nullable', 'string', 'max:100'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'status' => ['sometimes', Rule::in(['active', 'fallow', 'inactive'])],
            'notes' => ['nullable', 'string', 'max:4000'],
        ];
    }
}
