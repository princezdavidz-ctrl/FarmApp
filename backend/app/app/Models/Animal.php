<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Animal extends Model
{
    use HasFactory;

    protected $fillable = [
        'farm_id',
        'created_by',
        'tag',
        'name',
        'type',
        'sex',
        'status',
        'birth_date',
        'weight_kg',
        'is_pregnant',
        'last_dewormed_at',
        'last_vaccinated_at',
        'notes',
        'image_path',
    ];

    protected function casts(): array
    {
        return [
            'birth_date' => 'date',
            'is_pregnant' => 'boolean',
            'last_dewormed_at' => 'date',
            'last_vaccinated_at' => 'date',
        ];
    }

    /** @return BelongsTo<Farm, Animal> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    /** @return BelongsTo<User, Animal> */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /** @return HasMany<Pregnancy, Animal> */
    public function pregnancies(): HasMany
    {
        return $this->hasMany(Pregnancy::class, 'sow_id');
    }

    /** @return HasMany<PigListing> */
    public function pigListings(): HasMany
    {
        return $this->hasMany(PigListing::class);
    }
}
