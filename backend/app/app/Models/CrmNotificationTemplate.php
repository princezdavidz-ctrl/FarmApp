<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CrmNotificationTemplate extends Model
{
    protected $fillable = ['created_by', 'title', 'message', 'active'];

    protected function casts(): array
    {
        return ['active' => 'boolean'];
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
