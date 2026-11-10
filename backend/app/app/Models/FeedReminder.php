<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class FeedReminder extends Model
{
    protected $fillable = [
        'farm_id',
        'user_id',
        'schedule_id',
        'name',
        'minutes_after_midnight',
        'timezone',
        'enabled',
        'last_sent_on',
    ];

    protected function casts(): array
    {
        return [
            'minutes_after_midnight' => 'integer',
            'enabled' => 'boolean',
            'last_sent_on' => 'date',
        ];
    }

    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }
}
