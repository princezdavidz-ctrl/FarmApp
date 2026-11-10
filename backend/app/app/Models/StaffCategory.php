<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StaffCategory extends Model
{
    use HasFactory;

    protected $fillable = ['farm_id', 'name', 'slug', 'icon', 'color', 'active'];

    protected function casts(): array
    {
        return ['active' => 'boolean'];
    }

    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }
}
