<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CropActivity extends Model
{
    protected $fillable = [
        'farm_id', 'crop_cycle_id', 'activity_type', 'activity_date',
        'title', 'product_name', 'quantity', 'unit', 'cost', 'notes',
    ];

    protected function casts(): array
    {
        return [
            'activity_date' => 'date',
            'quantity' => 'decimal:3',
            'cost' => 'decimal:2',
        ];
    }

    /** @return BelongsTo<Farm, CropActivity> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    /** @return BelongsTo<CropCycle, CropActivity> */
    public function cropCycle(): BelongsTo
    {
        return $this->belongsTo(CropCycle::class);
    }
}
