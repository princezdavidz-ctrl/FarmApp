<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CrmPolicy extends Model
{
    use HasFactory;

    protected $fillable = [
        'farm_id',
        'title',
        'category',
        'audience',
        'status',
        'effective_date',
        'summary',
        'details',
        'notes',
        'visible_pages',
        'created_by',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'effective_date' => 'date:Y-m-d',
            'visible_pages' => 'array',
        ];
    }

    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function updater(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by');
    }
}
