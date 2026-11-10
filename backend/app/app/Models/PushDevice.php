<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PushDevice extends Model
{
    protected $fillable = ['user_id', 'token', 'token_hash', 'platform'];

    /** @return BelongsTo<User, PushDevice> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
