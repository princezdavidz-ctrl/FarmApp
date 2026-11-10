<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class HealthRecord extends Model
{
    use HasFactory;

    protected $fillable = [
        'farm_id',
        'animal_id',
        'type',
        'status',
        'rfid',
        'symptoms',
        'diagnosis',
        'medication',
        'dosage',
        'veterinarian',
        'visit_date',
        'next_checkup_date',
        'notes',
        'attachment_urls',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'symptoms' => 'array',
            'attachment_urls' => 'array',
            'visit_date' => 'datetime',
            'next_checkup_date' => 'datetime',
        ];
    }

    /** @return BelongsTo<Farm, HealthRecord> */
    public function farm(): BelongsTo
    {
        return $this->belongsTo(Farm::class);
    }

    /** @return BelongsTo<Animal, HealthRecord> */
    public function animal(): BelongsTo
    {
        return $this->belongsTo(Animal::class);
    }

    /** @return BelongsTo<User, HealthRecord> */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
