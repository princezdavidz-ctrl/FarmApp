<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Customer extends Model
{
    use HasFactory;

    protected $fillable = ['farm_id', 'created_by', 'assigned_user_id', 'name', 'email', 'phone', 'company', 'address', 'type', 'status', 'notes'];

    /** @return BelongsTo<Farm, Customer> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    /** @return BelongsTo<User, Customer> */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /** @return BelongsTo<User, Customer> */
    public function assignee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_user_id');
    }

    /** @return HasMany<CrmTask, Customer> */
    public function tasks(): HasMany
    {
        return $this->hasMany(CrmTask::class);
    }

    /** @return HasMany<CrmCustomerEvent, Customer> */
    public function events(): HasMany
    {
        return $this->hasMany(CrmCustomerEvent::class)->latest('occurred_at');
    }

    /** @return HasMany<CustomerInteraction, Customer> */
    public function interactions(): HasMany
    {
        return $this->hasMany(CustomerInteraction::class)->latest('occurred_at');
    }

    /** @return HasMany<CustomerOrder, Customer> */
    public function orders(): HasMany
    {
        return $this->hasMany(CustomerOrder::class);
    }
}
