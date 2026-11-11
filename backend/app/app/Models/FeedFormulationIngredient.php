<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class FeedFormulationIngredient extends Model
{
    protected $fillable = [
        'name', 'inclusion_percent', 'crude_protein_percent',
        'energy_mj_per_kg', 'cost_per_kg', 'position',
    ];

    protected function casts(): array
    {
        return [
            'inclusion_percent' => 'decimal:3',
            'crude_protein_percent' => 'decimal:3',
            'energy_mj_per_kg' => 'decimal:3',
            'cost_per_kg' => 'decimal:2',
            'position' => 'integer',
        ];
    }

    public function formulation(): BelongsTo
    {
        return $this->belongsTo(FeedFormulation::class, 'feed_formulation_id');
    }
}
