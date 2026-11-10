<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RefreshToken extends Model
{
    use HasFactory;

    protected $fillable = ['user_id', 'token_hash', 'remember_me', 'expires_at', 'revoked_at'];

    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'revoked_at' => 'datetime',
            'remember_me' => 'boolean',
        ];
    }

    /** @return BelongsTo<User, RefreshToken> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isValid(): bool
    {
        return $this->revoked_at === null && $this->expires_at->isFuture();
    }
}
