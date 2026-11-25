<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CropPlot extends Model
{
    protected $fillable = [
        'farm_id',
        'name',
        'area_acres',
        'soil_type',
        'irrigation_source',
        'latitude',
        'longitude',
        'status',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'area_acres' => 'decimal:2',
            'latitude' => 'decimal:7',
            'longitude' => 'decimal:7',
        ];
    }

    /** @return HasMany<CropCycle, CropPlot> */
    public function cropCycles(): HasMany
    {
        return $this->hasMany(CropCycle::class);
    }

    /** @return BelongsTo<Farm, CropPlot> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }
}
