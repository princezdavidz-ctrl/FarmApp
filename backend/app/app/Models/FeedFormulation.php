<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class FeedFormulation extends Model
{
    protected $fillable = ['farm_id', 'created_by', 'name', 'target_species', 'batch_size_kg', 'notes'];

    protected function casts(): array
    {
        return ['batch_size_kg' => 'decimal:2'];
    }

    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function ingredients(): HasMany
    {
        return $this->hasMany(FeedFormulationIngredient::class)->orderBy('position')->orderBy('id');
    }
}
