<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class FarmJobApplication extends Model
{
    protected $fillable = [
        'farm_job_posting_id', 'user_id', 'message', 'status',
    ];

    /** @return BelongsTo<FarmJobPosting, FarmJobApplication> */
    public function posting(): BelongsTo
    {
        return $this->belongsTo(FarmJobPosting::class, 'farm_job_posting_id');
    }

    /** @return BelongsTo<User, FarmJobApplication> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}