<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class SupportConversation extends Model
{
    protected $fillable = [
        'farm_id',
        'app_user_id',
        'customer_id',
        'assigned_user_id',
        'status',
        'last_message_at',
    ];

    protected function casts(): array
    {
        return ['last_message_at' => 'datetime'];
    }

    public function appUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'app_user_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class, 'customer_id');
    }

    public function assignee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_user_id');
    }

    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(SupportMessage::class, 'conversation_id')->oldest();
    }

    public function latestMessage(): HasOne
    {
        return $this->hasOne(SupportMessage::class, 'conversation_id')->latestOfMany();
    }
}