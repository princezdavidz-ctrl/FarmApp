<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CrmCustomerEvent extends Model
{
    protected $fillable = ['customer_id', 'user_id', 'type', 'data', 'occurred_at'];

    protected function casts(): array
    {
        return [
            'data' => 'array',
            'occurred_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Customer, CrmCustomerEvent> */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    /** @return BelongsTo<User, CrmCustomerEvent> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
