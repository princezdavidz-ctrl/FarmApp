<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DriverPayment extends Model
{
    protected $fillable = [
        'driver_profile_id', 'user_id', 'plan_code', 'duration_days', 'amount',
        'currency', 'phone', 'status', 'merchant_request_id', 'checkout_request_id',
        'mpesa_receipt', 'result_description', 'paid_at',
    ];

    protected function casts(): array
    {
        return ['amount' => 'decimal:2', 'duration_days' => 'integer', 'paid_at' => 'datetime'];
    }

    /** @return BelongsTo<DriverProfile, DriverPayment> */
    public function driverProfile(): BelongsTo
    {
        return $this->belongsTo(DriverProfile::class);
    }
}
