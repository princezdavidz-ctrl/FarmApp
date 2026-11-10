<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SupplierProfile extends Model
{
    protected $fillable = [
        'user_id', 'reference', 'business_registration_number', 'business_name',
        'county', 'product_categories', 'status', 'reviewed_by', 'reviewed_at',
        'review_note', 'subscription_paid_at', 'subscription_expires_at',
    ];

    protected function casts(): array
    {
        return [
            'reviewed_at' => 'datetime',
            'subscription_paid_at' => 'datetime',
            'subscription_expires_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<User, SupplierProfile> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return HasMany<SupplierProduct, SupplierProfile> */
    public function products(): HasMany
    {
        return $this->hasMany(SupplierProduct::class);
    }
}
