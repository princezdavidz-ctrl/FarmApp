<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DriverSubscriptionPlan extends Model
{
    protected $fillable = [
        'code', 'name', 'description', 'amount', 'currency', 'duration_days', 'active',
    ];

    protected function casts(): array
    {
        return ['amount' => 'decimal:2', 'duration_days' => 'integer', 'active' => 'boolean'];
    }
}
