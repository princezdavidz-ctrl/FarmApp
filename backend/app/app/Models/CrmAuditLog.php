<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CrmAuditLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'farm_id',
        'user_id',
        'action',
        'module',
        'metadata',
    ];

    protected function casts(): array
    {
        return ['metadata' => 'array'];
    }

    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
