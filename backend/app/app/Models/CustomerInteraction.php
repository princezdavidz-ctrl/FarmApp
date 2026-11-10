<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerInteraction extends Model
{
    use HasFactory;

    protected $fillable = ['customer_id', 'user_id', 'type', 'notes', 'occurred_at'];

    protected function casts(): array
    {
        return [
            'occurred_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Customer, CustomerInteraction> */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    /** @return BelongsTo<User, CustomerInteraction> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
