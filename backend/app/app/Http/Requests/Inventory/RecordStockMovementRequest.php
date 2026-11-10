<?php

namespace App\Http\Requests\Inventory;

use Illuminate\Foundation\Http\FormRequest;

class RecordStockMovementRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'type' => 'required|in:stock_in,stock_out,adjustment,expired',
            'quantity' => 'required|numeric|min:0.01',
            'reference' => 'nullable|string|max:255',
            'notes' => 'nullable|string',
        ];
    }
}
