<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class FeedUsage extends Model
{
    use HasFactory;

    protected $fillable = ['farm_id', 'feed_stock_id', 'created_by', 'quantity', 'unit', 'used_at', 'notes'];

    protected function casts(): array
    {
        return ['quantity' => 'decimal:2', 'used_at' => 'datetime'];
    }

    public function stock(): BelongsTo { return $this->belongsTo(FeedStock::class, 'feed_stock_id'); }
    public function farm(): BelongsTo { return $this->belongsTo(Farm::class); }
}
