<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerOrder extends Model
{
    use HasFactory;

    protected $fillable = [
        'farm_id', 'customer_id', 'reference', 'status', 'items', 'total_amount',
        'currency', 'ordered_at', 'expected_at', 'completed_at', 'notes',
        'created_by', 'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'items' => 'array',
            'total_amount' => 'decimal:2',
            'ordered_at' => 'date',
            'expected_at' => 'date',
            'completed_at' => 'date',
        ];
    }

    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function updater(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by');
    }
}
