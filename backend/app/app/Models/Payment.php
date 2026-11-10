<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Model;

class Payment extends Model
{
    protected $fillable = [
        'farm_id', 'user_id', 'plan_code', 'mother_pig_count', 'amount', 'currency',
        'phone', 'status', 'merchant_request_id', 'checkout_request_id',
        'mpesa_receipt', 'result_description', 'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'mother_pig_count' => 'integer',
            'paid_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Farm, Payment> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    /** @return BelongsTo<User, Payment> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}