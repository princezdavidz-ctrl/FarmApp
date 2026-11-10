<?php

namespace App\Http\Requests\Feed;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreFeedUsageRequest extends FormRequest
{
    public function authorize(): bool { return true; }

    public function rules(): array
    {
        return [
            'feed_stock_id' => ['nullable', 'integer', Rule::exists('feed_stocks', 'id')],
            'quantity' => ['required', 'numeric', 'gt:0'],
            'unit' => ['required', 'string', 'max:20'],
            'used_at' => ['required', 'date'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ];
    }
}
