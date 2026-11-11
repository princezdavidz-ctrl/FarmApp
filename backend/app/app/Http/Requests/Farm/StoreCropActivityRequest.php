<?php

namespace App\Http\Requests\Farm;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreCropActivityRequest extends FormRequest
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
                'nullable',
                Rule::exists('crop_cycles', 'id')->where('farm_id', $farmId),
            ],
            'activity_type' => ['required', Rule::in([
                'irrigation', 'fertilizer', 'pesticide', 'herbicide',
                'weeding', 'pruning', 'scouting', 'planting', 'harvest', 'other',
            ])],
            'activity_date' => ['required', 'date'],
            'title' => ['required', 'string', 'max:160'],
            'product_name' => ['nullable', 'string', 'max:160'],
            'quantity' => ['nullable', 'numeric', 'gt:0'],
            'unit' => ['nullable', 'string', 'max:40'],
            'cost' => ['nullable', 'numeric', 'gte:0'],
            'notes' => ['nullable', 'string', 'max:4000'],
        ];
    }
}
