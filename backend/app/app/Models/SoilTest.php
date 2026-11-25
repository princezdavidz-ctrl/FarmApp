<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SoilTest extends Model
{
    protected $fillable = [
        'crop_plot_id', 'sampled_at', 'laboratory_name', 'ph',
        'nitrogen_ppm', 'phosphorus_ppm', 'potassium_ppm',
        'organic_matter_percent', 'moisture_percent', 'recommendations', 'notes',
    ];

    protected function casts(): array
    {
        return [
            'sampled_at' => 'date:Y-m-d',
            'ph' => 'decimal:2',
            'nitrogen_ppm' => 'decimal:2',
            'phosphorus_ppm' => 'decimal:2',
            'potassium_ppm' => 'decimal:2',
            'organic_matter_percent' => 'decimal:2',
            'moisture_percent' => 'decimal:2',
        ];
    }

    /** @return BelongsTo<CropPlot, SoilTest> */
    public function cropPlot(): BelongsTo
    {
        return $this->belongsTo(CropPlot::class);
    }
}
