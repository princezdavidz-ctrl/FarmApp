<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TransportRequest extends Model
{
    protected $fillable = [
        'requester_user_id', 'farm_id', 'supplier_profile_id', 'driver_profile_id',
        'service_type', 'vehicle_type', 'pickup_latitude', 'pickup_longitude',
        'pickup_address', 'destination_latitude', 'destination_longitude',
        'destination_address', 'load_description', 'radius_km', 'status',
    ];

    protected function casts(): array
    {
        return [
            'pickup_latitude' => 'float',
            'pickup_longitude' => 'float',
            'destination_latitude' => 'float',
            'destination_longitude' => 'float',
            'radius_km' => 'integer',
        ];
    }

    /** @return BelongsTo<User, TransportRequest> */
    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requester_user_id');
    }

    /** @return BelongsTo<DriverProfile, TransportRequest> */
    public function driver(): BelongsTo
    {
        return $this->belongsTo(DriverProfile::class, 'driver_profile_id');
    }
}
