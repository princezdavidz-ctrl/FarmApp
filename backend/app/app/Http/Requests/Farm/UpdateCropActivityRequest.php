<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCropActivityRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $farmId = $this->route('farm')?->id;

        return [
            'crop_cycle_id' => [
                'sometimes', 'nullable',
                Rule::exists('crop_cycles', 'id')->where('farm_id', $farmId),
            ],
            'activity_type' => ['sometimes', 'required', Rule::in([
                'irrigation', 'fertilizer', 'pesticide', 'herbicide',
                'weeding', 'pruning', 'scouting', 'planting', 'harvest', 'other',
            ])],
            'activity_date' => ['sometimes', 'required', 'date'],
            'title' => ['sometimes', 'required', 'string', 'max:160'],
            'product_name' => ['sometimes', 'nullable', 'string', 'max:160'],
            'quantity' => ['sometimes', 'nullable', 'numeric', 'gt:0'],
            'unit' => ['sometimes', 'nullable', 'string', 'max:40'],
            'cost' => ['sometimes', 'nullable', 'numeric', 'gte:0'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:4000'],
        ];
    }
}
