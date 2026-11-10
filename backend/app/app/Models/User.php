<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use App\Notifications\PasswordResetNotification;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Collection;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'phone', 'password', 'role', 'crm_role', 'crm_closed_at', 'avatar_path'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /** @return BelongsToMany<Farm, User> */
    public function farms(): BelongsToMany
    {
        return $this->belongsToMany(Farm::class)->withPivot(['permissions', 'role'])->withTimestamps();
    }

    public function buyer(): HasOne
    {
        return $this->hasOne(Buyer::class);
    }

    /** @return HasOne<VeterinarianProfile, User> */
    public function veterinarianProfile(): HasOne
    {
        return $this->hasOne(VeterinarianProfile::class);
    }

    /** @return HasOne<SupplierProfile, User> */
    public function supplierProfile(): HasOne
    {
        return $this->hasOne(SupplierProfile::class);
    }

    /** @return HasOne<DriverProfile, User> */
    public function driverProfile(): HasOne
    {
        return $this->hasOne(DriverProfile::class);
    }

    /** @return HasMany<FarmJoinRequest, User> */
    public function farmJoinRequests(): HasMany
    {
        return $this->hasMany(FarmJoinRequest::class);
    }

    /** @return HasMany<RefreshToken, User> */
    public function refreshTokens(): HasMany
    {
        return $this->hasMany(RefreshToken::class);
    }

    /**
     * Backward-compatible accessor for legacy code that still expects a user-level
     * farm-members collection.
     *
     * @return Collection<int, User>
     */
    public function farmMembers()
    {
        return $this->farms()
            ->with('users')
            ->get()
            ->flatMap(fn (Farm $farm) => $farm->users)
            ->unique('id')
            ->values();
    }

    public function sendPasswordResetNotification(#[\SensitiveParameter] $token): void
    {
        $this->notify(new PasswordResetNotification($token));
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'crm_closed_at' => 'datetime',
            'crm_online_until' => 'datetime',
        ];
    }
}
