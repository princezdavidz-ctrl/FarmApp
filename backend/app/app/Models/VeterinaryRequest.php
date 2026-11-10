<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class VeterinaryRequest extends Model
{
    protected $fillable = [
        'requester_user_id', 'farm_id', 'veterinarian_profile_id', 'county',
        'animal_type', 'animal_name', 'issue_description', 'location',
        'latitude', 'longitude', 'status',
    ];

    protected function casts(): array
    {
        return [
            'latitude' => 'float',
            'longitude' => 'float',
        ];
    }

    /** @return BelongsTo<User, VeterinaryRequest> */
    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requester_user_id');
    }

    /** @return BelongsTo<Farm, VeterinaryRequest> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    /** @return BelongsTo<VeterinarianProfile, VeterinaryRequest> */
    public function veterinarian(): BelongsTo
    {
        return $this->belongsTo(VeterinarianProfile::class);
    }
}
