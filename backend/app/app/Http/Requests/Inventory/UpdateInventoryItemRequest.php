<?php

namespace App\Http\Requests\Inventory;

use Illuminate\Foundation\Http\FormRequest;

class UpdateInventoryItemRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $data = $this->all();

        foreach (['minimumLevel' => 'minimum_level', 'costPrice' => 'cost_price', 'expiryDate' => 'expiry_date', 'storageLocation' => 'storage_location'] as $camel => $snake) {
            if (array_key_exists($camel, $data) && ! array_key_exists($snake, $data)) {
                $data[$snake] = $data[$camel];
            }
        }

        $this->replace($data);
    }

    public function rules(): array
    {
        return [
            'name' => 'sometimes|string|max:255',
            'category' => 'sometimes|in:Feed,Medicine,Vaccines,Equipment,Cleaning,RFID,Other',
            'sku' => 'sometimes|string|unique:inventory_items,sku,' . $this->route('item')->id,
            'barcode' => 'sometimes|nullable|string|unique:inventory_items,barcode,' . $this->route('item')->id,
            'quantity' => 'sometimes|numeric|min:0',
            'unit' => 'sometimes|string|max:50',
            'minimum_level' => 'sometimes|numeric|min:0',
            'cost_price' => 'sometimes|numeric|min:0',
            'supplier' => 'sometimes|nullable|string|max:255',
            'expiry_date' => 'sometimes|nullable|date',
            'storage_location' => 'sometimes|nullable|string|max:255',
            'notes' => 'sometimes|nullable|string',
        ];
    }
}
