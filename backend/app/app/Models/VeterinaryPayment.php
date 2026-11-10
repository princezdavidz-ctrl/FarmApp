<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class VeterinaryPayment extends Model
{
    protected $fillable = [
        'veterinarian_profile_id', 'user_id', 'plan_code', 'duration_days', 'amount', 'currency',
        'phone', 'status', 'merchant_request_id', 'checkout_request_id',
        'mpesa_receipt', 'result_description', 'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'duration_days' => 'integer',
            'paid_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<VeterinarianProfile, VeterinaryPayment> */
    public function veterinarianProfile(): BelongsTo
    {
        return $this->belongsTo(VeterinarianProfile::class);
    }

    /** @return BelongsTo<User, VeterinaryPayment> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
