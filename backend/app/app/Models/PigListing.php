<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PigListing extends Model
{
    use HasFactory;

    protected $fillable = [
        'farm_id',
        'animal_id',
        'title',
        'breed',
        'age_weeks',
        'weight_kg',
        'quantity',
        'price_per_pig',
        'currency',
        'location',
        'description',
        'status',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'age_weeks' => 'integer',
            'weight_kg' => 'decimal:2',
            'quantity' => 'integer',
            'price_per_pig' => 'decimal:2',
        ];
    }

    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    public function animal(): BelongsTo
    {
        return $this->belongsTo(Animal::class);
    }

    public function inquiries(): HasMany
    {
        return $this->hasMany(PigInquiry::class);
    }
}
