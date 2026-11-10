<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Pregnancy extends Model
{
    use HasFactory;

    protected $fillable = [
        'farm_id',
        'sow_id',
        'boar_id',
        'created_by',
        'mating_date',
        'semen_used',
        'confirmation_date',
        'expected_farrowing_date',
        'actual_farrowing_date',
        'status',
        'expected_litter_size',
        'born_alive',
        'stillborn',
        'mummified',
        'weaned',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'mating_date' => 'date',
            'confirmation_date' => 'date',
            'expected_farrowing_date' => 'date',
            'actual_farrowing_date' => 'date',
            'expected_litter_size' => 'integer',
            'born_alive' => 'integer',
            'stillborn' => 'integer',
            'mummified' => 'integer',
            'weaned' => 'integer',
        ];
    }

    /** @return BelongsTo<Farm, Pregnancy> */
    public function farm(): BelongsTo { return $this->belongsTo(Farm::class); }

    /** @return BelongsTo<Animal, Pregnancy> */
    public function sow(): BelongsTo { return $this->belongsTo(Animal::class, 'sow_id'); }

    /** @return BelongsTo<Animal, Pregnancy> */
    public function boar(): BelongsTo { return $this->belongsTo(Animal::class, 'boar_id'); }

    /** @return BelongsTo<User, Pregnancy> */
    public function creator(): BelongsTo { return $this->belongsTo(User::class, 'created_by'); }
}