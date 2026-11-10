<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class FarmNotification extends Model
{
    use HasFactory;

    protected $fillable = [
        'farm_id',
        'recipient_id',
        'type',
        'title',
        'body',
        'severity',
        'related_type',
        'related_id',
        'action_route',
        'read_at',
    ];

    protected function casts(): array
    {
        return ['read_at' => 'datetime'];
    }

    public function farm(): BelongsTo { return $this->belongsTo(Farm::class); }
    public function recipient(): BelongsTo { return $this->belongsTo(User::class, 'recipient_id'); }
}