<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCropPlotRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $farmId = $this->route('farm')?->id;
        $plotId = $this->route('cropPlot')?->id;

        return [
            'name' => [
                'sometimes', 'required', 'string', 'max:120',
                Rule::unique('crop_plots', 'name')->where('farm_id', $farmId)->ignore($plotId),
            ],
            'area_acres' => ['sometimes', 'required', 'numeric', 'gt:0', 'max:100000'],
            'soil_type' => ['sometimes', 'nullable', 'string', 'max:80'],
            'irrigation_source' => ['sometimes', 'nullable', 'string', 'max:100'],
            'latitude' => ['sometimes', 'nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'nullable', 'numeric', 'between:-180,180'],
            'status' => ['sometimes', Rule::in(['active', 'fallow', 'inactive'])],
            'notes' => ['sometimes', 'nullable', 'string', 'max:4000'],
        ];
    }
}
