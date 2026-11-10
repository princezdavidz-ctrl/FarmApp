<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class InventoryItem extends Model
{
    use HasFactory;

    protected $table = 'inventory_items';

    protected $fillable = [
        'farm_id',
        'name',
        'category',
        'sku',
        'barcode',
        'quantity',
        'unit',
        'minimum_level',
        'cost_price',
        'supplier',
        'expiry_date',
        'storage_location',
        'notes',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'decimal:2',
            'minimum_level' => 'decimal:2',
            'cost_price' => 'decimal:2',
            'expiry_date' => 'datetime',
        ];
    }

    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    public function movements(): HasMany
    {
        return $this->hasMany(InventoryMovement::class);
    }

    public function createdBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function isLowStock(): bool
    {
        return (float) $this->quantity <= (float) $this->minimum_level;
    }

    public function isExpired(): bool
    {
        return $this->expiry_date && $this->expiry_date->isPast();
    }

    public function isExpiringSoon(): bool
    {
        if (!$this->expiry_date) return false;
        return $this->expiry_date->diffInDays(now()) <= 30 && !$this->isExpired();
    }

    public function inventoryValue(): float
    {
        return (float) $this->quantity * (float) $this->cost_price;
    }
}
