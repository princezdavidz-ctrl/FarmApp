<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class FarmTask extends Model
{
    use HasFactory;

    protected $fillable = [
        'farm_id', 'assigned_to', 'created_by', 'title', 'notes', 'due_at',
        'priority', 'category', 'status', 'completed_at',
    ];

    protected function casts(): array
    {
        return [
            'due_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Farm, FarmTask> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    /** @return BelongsTo<User, FarmTask> */
    public function assignee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }

    /** @return BelongsTo<User, FarmTask> */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
