<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BuyerNotification extends Model
{
    protected $fillable = [
        'buyer_user_id', 'pig_inquiry_id', 'transport_request_id',
        'type', 'title', 'body', 'action_route', 'read_at',
    ];

    protected function casts(): array
    {
        return ['read_at' => 'datetime'];
    }

    public function buyer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'buyer_user_id');
    }

    public static function notifyInquiry(
        ?PigInquiry $inquiry,
        string $type,
        string $title,
        string $body,
        string $section = 'delivery',
    ): void {
        if ($inquiry === null || $inquiry->buyer_user_id === null) {
            return;
        }

        static::create([
            'buyer_user_id' => $inquiry->buyer_user_id,
            'pig_inquiry_id' => $inquiry->id,
            'transport_request_id' => $inquiry->transportRequest?->id,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'action_route' => '/buyer/deliveries',
        ]);
    }
}
