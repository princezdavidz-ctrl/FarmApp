<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DriverProfile extends Model
{
    protected $fillable = [
        'user_id', 'reference', 'driver_license_number', 'county', 'service_types',
        'vehicle_type', 'vehicle_registration_number', 'capacity_description',
        'status', 'reviewed_by', 'reviewed_at', 'review_note',
        'subscription_paid_at', 'subscription_expires_at', 'latitude', 'longitude',
        'available', 'location_updated_at',
    ];

    protected function casts(): array
    {
        return [
            'reviewed_at' => 'datetime',
            'subscription_paid_at' => 'datetime',
            'subscription_expires_at' => 'datetime',
            'location_updated_at' => 'datetime',
            'available' => 'boolean',
        ];
    }

    /** @return BelongsTo<User, DriverProfile> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
