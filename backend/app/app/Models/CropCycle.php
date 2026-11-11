<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CropCycle extends Model
{
    protected $fillable = [
        'farm_id', 'plot_name', 'crop_name', 'variety', 'area_acres',
        'planting_date', 'expected_harvest_date', 'actual_harvest_date',
        'status', 'expected_yield_kg', 'actual_yield_kg', 'actual_revenue_kes', 'notes',
    ];

    protected function casts(): array
    {
        return [
            'area_acres' => 'decimal:2',
            'planting_date' => 'date',
            'expected_harvest_date' => 'date',
            'actual_harvest_date' => 'date',
            'expected_yield_kg' => 'decimal:2',
            'actual_yield_kg' => 'decimal:2',
            'actual_revenue_kes' => 'decimal:2',
        ];
    }

    /** @return BelongsTo<Farm, CropCycle> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    /** @return HasMany<CropActivity, CropCycle> */
    public function activities(): HasMany
    {
        return $this->hasMany(CropActivity::class);
    }
}
