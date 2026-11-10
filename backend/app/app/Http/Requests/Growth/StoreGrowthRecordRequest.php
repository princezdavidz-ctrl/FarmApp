<?php

namespace App\Http\Requests\Growth;

use Illuminate\Foundation\Http\FormRequest;

class StoreGrowthRecordRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'animal_id' => ['required', 'exists:animals,id'],
            'rfid' => ['nullable', 'string', 'max:100'],
            'current_weight' => ['required', 'numeric', 'min:0'],
            'previous_weight' => ['nullable', 'numeric', 'min:0'],
            'weight_gain' => ['nullable', 'numeric'],
            'daily_gain' => ['nullable', 'numeric'],
            'age_in_days' => ['nullable', 'integer', 'min:0'],
            'measurement_date' => ['required', 'date_format:Y-m-d\TH:i:s\Z'],
            'recorded_by' => ['nullable', 'string', 'max:200'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'photo_url' => ['nullable', 'url', 'max:500'],
            'target_weight' => ['nullable', 'numeric', 'min:0'],
        ];
    }
}
