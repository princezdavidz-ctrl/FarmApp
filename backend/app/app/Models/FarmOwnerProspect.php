<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class FarmOwnerProspect extends Model
{
    protected $fillable = ['created_by', 'owner_name', 'email', 'phone', 'farm_name', 'status', 'notes'];

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
