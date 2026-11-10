<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class FarmJobPosting extends Model
{
    protected $fillable = [
        'farm_id', 'created_by', 'role', 'title', 'description', 'location', 'status',
    ];

    /** @return BelongsTo<Farm, FarmJobPosting> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    /** @return HasMany<FarmJobApplication, FarmJobPosting> */
    public function applications(): HasMany
    {
        return $this->hasMany(FarmJobApplication::class);
    }
}