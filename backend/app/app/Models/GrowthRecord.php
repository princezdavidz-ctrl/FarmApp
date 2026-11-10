<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class GrowthRecord extends Model
{
    use HasFactory;

    protected $fillable = [
        'farm_id',
        'animal_id',
        'rfid',
        'current_weight',
        'previous_weight',
        'weight_gain',
        'daily_gain',
        'age_in_days',
        'measurement_date',
        'recorded_by',
        'notes',
        'photo_url',
        'target_weight',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'current_weight' => 'float',
            'previous_weight' => 'float',
            'weight_gain' => 'float',
            'daily_gain' => 'float',
            'measurement_date' => 'datetime',
            'target_weight' => 'float',
        ];
    }

    /** @return BelongsTo<Farm, GrowthRecord> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    /** @return BelongsTo<Animal, GrowthRecord> */
    public function animal(): BelongsTo
    {
        return $this->belongsTo(Animal::class);
    }

    /** @return BelongsTo<User, GrowthRecord> */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
