<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

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

    /** @return BelongsTo<Farm, CropPlot> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }
}
