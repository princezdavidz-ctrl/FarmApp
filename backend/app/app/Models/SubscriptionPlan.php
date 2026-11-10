<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SubscriptionPlan extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'name',
        'description',
        'amount',
        'currency',
        'pig_limit',
        'active',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'pig_limit' => 'integer',
            'active' => 'boolean',
        ];
    }
}