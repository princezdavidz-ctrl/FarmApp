<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SupplierProduct extends Model
{
    protected $fillable = [
        'supplier_profile_id', 'name', 'category', 'description', 'price',
        'currency', 'unit', 'stock_quantity', 'active',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'stock_quantity' => 'integer',
            'active' => 'boolean',
        ];
    }

    /** @return BelongsTo<SupplierProfile, SupplierProduct> */
    public function supplierProfile(): BelongsTo
    {
        return $this->belongsTo(SupplierProfile::class);
    }
}
