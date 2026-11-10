<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PigInquiry extends Model
{
    use HasFactory;

    protected $fillable = [
        'buyer_id',
        'buyer_user_id',
        'buyer_name',
        'phone',
        'email',
        'quantity',
        'message',
        'status',
    ];

    protected function casts(): array
    {
        return ['quantity' => 'integer'];
    }

    public function listing(): BelongsTo
    {
        return $this->belongsTo(PigListing::class, 'pig_listing_id');
    }

    public function buyer(): BelongsTo
    {
        return $this->belongsTo(Buyer::class);
    }
}
