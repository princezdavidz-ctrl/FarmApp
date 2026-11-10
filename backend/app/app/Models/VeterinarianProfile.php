<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class VeterinarianProfile extends Model
{
    protected $fillable = [
        'user_id', 'reference', 'license_number', 'clinic_name', 'county',
        'specialization', 'years_experience', 'status', 'reviewed_by',
        'reviewed_at', 'review_note', 'subscription_paid_at', 'subscription_expires_at',
    ];

    protected function casts(): array
    {
        return [
            'years_experience' => 'integer',
            'reviewed_at' => 'datetime',
            'subscription_paid_at' => 'datetime',
            'subscription_expires_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<User, VeterinarianProfile> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return BelongsTo<User, VeterinarianProfile> */
    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    /** @return HasMany<VeterinaryPayment, VeterinarianProfile> */
    public function payments(): HasMany
    {
        return $this->hasMany(VeterinaryPayment::class);
    }
}
