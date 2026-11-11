<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Farm extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'location',
        'latitude',
        'longitude',
        'created_by',
        'invite_code',
        'mother_pig_count',
        'piglet_groups',
        'pregnant_pig_count',
        'subscription_plan',
        'farming_type',
        'production_types',
    ];

    protected function casts(): array
    {
        return [
            'mother_pig_count' => 'integer',
            'latitude' => 'float',
            'longitude' => 'float',
            'piglet_groups' => 'array',
            'pregnant_pig_count' => 'integer',
            'production_types' => 'array',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Farm $farm) {
            $farm->invite_code ??= self::generateInviteCode();
        });
    }

    public static function generateInviteCode(): string
    {
        do {
            $code = Str::upper(Str::random(8));
        } while (self::where('invite_code', $code)->exists());

        return $code;
    }

    /** @return BelongsToMany<User, Farm> */
    public function users(): BelongsToMany
    {
        return $this->belongsToMany(User::class)->withPivot(['permissions', 'role'])->withTimestamps();
    }

    public function createdBy(): \Illuminate\Database\Eloquent\Relations\BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /** @return HasMany<FarmJoinRequest, Farm> */
    public function joinRequests(): HasMany
    {
        return $this->hasMany(FarmJoinRequest::class);
    }

    /** @return HasMany<Customer, Farm> */
    public function customers(): HasMany
    {
        return $this->hasMany(Customer::class);
    }

    /** @return HasMany<CustomerOrder, Farm> */
    public function customerOrders(): HasMany
    {
        return $this->hasMany(CustomerOrder::class);
    }

    /** @return HasMany<PigListing, Farm> */
    public function pigListings(): HasMany
    {
        return $this->hasMany(PigListing::class);
    }

    /** @return HasMany<Animal, Farm> */
    public function animals(): HasMany
    {
        return $this->hasMany(Animal::class);
    }

    /** @return HasMany<Pregnancy, Farm> */
    public function pregnancies(): HasMany
    {
        return $this->hasMany(Pregnancy::class);
    }

    public function feedStocks(): HasMany
    {
        return $this->hasMany(FeedStock::class);
    }

    public function feedUsages(): HasMany
    {
        return $this->hasMany(FeedUsage::class);
    }

    /** @return HasMany<FeedFormulation, Farm> */
    public function feedFormulations(): HasMany
    {
        return $this->hasMany(FeedFormulation::class);
    }

    /** @return HasMany<Payment, Farm> */
    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    /** @return HasMany<HealthRecord, Farm> */
    public function healthRecords(): HasMany
    {
        return $this->hasMany(HealthRecord::class);
    }

    /** @return HasMany<GrowthRecord, Farm> */
    public function growthRecords(): HasMany
    {
        return $this->hasMany(GrowthRecord::class);
    }

    /** @return HasMany<InventoryItem, Farm> */
    public function inventoryItems(): HasMany
    {
        return $this->hasMany(InventoryItem::class);
    }

    /** @return HasMany<CropCycle, Farm> */
    public function cropCycles(): HasMany
    {
        return $this->hasMany(CropCycle::class);
    }

    /** @return HasMany<CropActivity, Farm> */
    public function cropActivities(): HasMany
    {
        return $this->hasMany(CropActivity::class);
    }

    /** @return HasMany<FarmTask, Farm> */
    public function tasks(): HasMany
    {
        return $this->hasMany(FarmTask::class);
    }

    /** @return HasMany<FarmFinanceTransaction, Farm> */
    public function financeTransactions(): HasMany
    {
        return $this->hasMany(FarmFinanceTransaction::class);
    }
}
