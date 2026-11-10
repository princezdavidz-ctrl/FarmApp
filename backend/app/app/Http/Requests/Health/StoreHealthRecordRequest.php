<?php

namespace App\Http\Requests\Health;

use App\Models\Farm;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreHealthRecordRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $farm = $this->route('farm');
        $farmId = $farm instanceof Farm ? $farm->id : $farm;

        return [
            'animal_id' => [
                'required_without:pig_id',
                'nullable',
                'integer',
                Rule::exists('animals', 'id')->where('farm_id', $farmId),
            ],
            'pig_id' => ['required_without:animal_id', 'nullable', 'string', 'max:50'],
            'type' => ['required', Rule::in(['vaccination', 'treatment', 'deworming', 'mortality'])],
            'status' => ['required', Rule::in(['healthy', 'recovering', 'critical', 'deceased'])],
            'rfid' => ['nullable', 'string', 'max:100'],
            'symptoms' => ['nullable', 'array'],
            'symptoms.*' => ['string', 'max:100'],
            'diagnosis' => ['nullable', 'string', 'max:1000'],
            'medication' => ['nullable', 'string', 'max:200'],
            'dosage' => ['nullable', 'string', 'max:200'],
            'veterinarian' => ['nullable', 'string', 'max:200'],
            'visit_date' => ['nullable', 'date', 'before_or_equal:now'],
            'next_checkup_date' => ['nullable', 'date'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'attachment_urls' => ['nullable', 'array'],
            'attachment_urls.*' => ['url', 'max:500'],
        ];
    }
}
