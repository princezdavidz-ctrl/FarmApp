<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LoginOtp extends Model
{
    protected $fillable = [
        'challenge_id',
        'user_id',
        'code_hash',
        'remember_me',
        'attempts',
        'expires_at',
        'consumed_at',
    ];

    protected function casts(): array
    {
        return [
            'remember_me' => 'boolean',
            'attempts' => 'integer',
            'expires_at' => 'datetime',
            'consumed_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<User, LoginOtp> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
