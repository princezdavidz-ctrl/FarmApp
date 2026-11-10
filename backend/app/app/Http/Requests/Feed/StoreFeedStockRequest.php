<?php

namespace App\Http\Requests\Feed;

use Illuminate\Foundation\Http\FormRequest;

class StoreFeedStockRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'quantity' => ['required', 'numeric', 'gt:0'],
            'unit' => ['required', 'string', 'max:20'],
            'unit_cost' => ['nullable', 'numeric', 'gte:0'],
            'location' => ['nullable', 'string', 'max:255'],
        ];
    }
}
