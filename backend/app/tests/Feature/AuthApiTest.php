<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\RefreshToken;
use App\Models\User;
use App\Notifications\LoginOtpNotification;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class AuthApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_register_with_a_phone_and_login_by_phone(): void
    {
        $registration = $this->postJson('/api/v1/auth/register', [
            'name' => 'Owner',
            'email' => 'owner@example.com',
            'phone' => '+15551234567',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'farmOwner',
            'farm_name' => 'Green Valley Farm',
        ]);

        $registration->assertOk()
            ->assertJsonPath('user.phone', '+15551234567')
            ->assertJsonPath('user.role', 'farmOwner')
            ->assertJsonPath('farms.0.name', 'Green Valley Farm');
        $this->assertDatabaseHas('farm_notifications', [
            'farm_id' => $registration->json('farms.0.id'),
            'recipient_id' => $registration->json('user.id'),
            'type' => 'welcome',
            'title' => 'Welcome Owner to FarmApp',
            'body' => 'We will be with you all the way.',
        ]);

        Notification::fake();
        $login = $this->beginOtpLogin('+15551234567', 'password123');
        $this->assertDatabaseHas('login_otps', ['user_id' => $registration->json('user.id')]);
        $verified = $this->verifyOtpLogin($login, User::findOrFail($registration->json('user.id')));
        $verified->assertOk()->assertJsonStructure([
            'access_token',
            'refresh_token',
            'user' => ['id', 'phone', 'role'],
            'farms',
        ]);
    }

    public function test_owner_can_register_with_the_mobile_onboarding_payload(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'name' => 'Mobile Owner',
            'email' => 'mobile-owner@example.com',
            'phone' => '+254712345678',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'farmOwner',
            'farm_name' => 'Mobile Farm',
            'mother_pig_count' => 12,
            'piglet_groups' => [
                ['count' => 8, 'age_months' => 3],
            ],
            'pregnant_pig_count' => 4,
        ])->assertOk()
            ->assertJsonPath('user.phone', '+254712345678')
            ->assertJsonPath('farms.0.name', 'Mobile Farm')
            ->assertJsonPath('farms.0.mother_pig_count', 12)
            ->assertJsonPath('farms.0.piglet_groups.0.count', 8)
            ->assertJsonPath('farms.0.piglet_groups.0.age_months', 3)
            ->assertJsonPath('farms.0.pregnant_pig_count', 4);
    }

    public function test_buyer_can_register_and_complete_otp_login(): void
    {
        Notification::fake();
        $registration = $this->postJson('/api/v1/auth/register', [
            'name' => 'Marketplace Buyer',
            'email' => 'buyer-login@example.com',
            'phone' => '+254700000888',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'buyer',
        ])->assertOk()->assertJsonPath('user.role', 'buyer');

        $buyer = User::findOrFail($registration->json('user.id'));
        $this->assertDatabaseHas('buyers', ['user_id' => $buyer->id]);

        $challenge = $this->beginOtpLogin($buyer->email, 'password123');
        $this->verifyOtpLogin($challenge, $buyer)
            ->assertOk()
            ->assertJsonPath('user.id', (string) $buyer->id)
            ->assertJsonPath('user.role', 'buyer');
    }

    public function test_new_invited_farm_member_receives_a_personal_welcome_notification(): void
    {
        $farm = Farm::create(['name' => 'Invite Farm']);

        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'New Manager',
            'email' => 'manager@example.com',
            'phone' => '+254700000123',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'farmManager',
            'invite_code' => $farm->invite_code,
        ])->assertOk();

        $this->assertDatabaseHas('farm_notifications', [
            'farm_id' => $farm->id,
            'recipient_id' => $response->json('user.id'),
            'type' => 'welcome',
            'title' => 'Welcome New Manager to FarmApp',
            'body' => 'We will be with you all the way.',
        ]);
    }

    public function test_authenticated_user_can_upload_a_persisted_profile_avatar(): void
    {
        Storage::fake('public');
        $user = User::factory()->create();

        $upload = $this->actingAs($user, 'sanctum')
            ->post('/api/v1/auth/profile/avatar', [
                'avatar' => UploadedFile::fake()->create('profile.png', 10, 'image/png'),
            ])
            ->assertOk()
            ->assertJsonPath('user.id', (string) $user->id);
        $this->assertStringContainsString('/storage/profile-avatars/', $upload->json('user.avatar_url'));

        $user->refresh();
        $this->assertNotNull($user->avatar_path);
        Storage::disk('public')->assertExists($user->avatar_path);
        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('user.avatar_url', Storage::disk('public')->url($user->avatar_path));
    }

    public function test_registration_schema_repair_migration_restores_columns_missing_from_a_partial_deployment(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropIndex('users_phone_index');
            $table->dropColumn('phone');
        });
        Schema::table('farms', function (Blueprint $table): void {
            $table->dropUnique('farms_invite_code_unique');
            $table->dropColumn([
                'invite_code',
                'mother_pig_count',
                'piglet_groups',
                'pregnant_pig_count',
            ]);
        });
        Schema::table('farm_user', function (Blueprint $table): void {
            $table->dropColumn(['permissions', 'role']);
        });

        $migration = require database_path('migrations/2026_10_07_000001_repair_registration_schema.php');
        $migration->up();
        $migration->up();

        foreach ([
            'mother_pig_count',
            'piglet_groups',
            'pregnant_pig_count',
        ] as $column) {
            $this->assertTrue(Schema::hasColumn('farms', $column), "Missing farms.$column");
        }

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Repaired Owner',
            'email' => 'repaired-owner@example.com',
            'phone' => '+15551234568',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'farmOwner',
            'farm_name' => 'Repaired Farm',
        ])->assertOk()
            ->assertJsonPath('user.phone', '+15551234568')
            ->assertJsonPath('farms.0.name', 'Repaired Farm');
    }

    public function test_subscription_plan_repair_migration_restores_a_missing_farm_column(): void
    {
        Schema::table('farms', function (Blueprint $table): void {
            $table->dropColumn('subscription_plan');
        });

        $migration = require database_path('migrations/2026_10_27_000001_repair_farm_subscription_plan_column.php');
        $migration->up();
        $migration->up();

        $this->assertTrue(Schema::hasColumn('farms', 'subscription_plan'));
    }

    public function test_farm_owner_can_register_only_one_farm_per_account(): void
    {
        $payload = [
            'name' => 'Owner',
            'email' => 'owner@example.com',
            'phone' => '+15551234567',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'farmOwner',
            'farm_name' => 'First Farm',
        ];

        $this->postJson('/api/v1/auth/register', $payload)->assertOk();
        $this->postJson('/api/v1/auth/register', [...$payload, 'farm_name' => 'Second Farm'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('farm_name');

        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseCount('farms', 1);
    }

    public function test_existing_identity_requires_the_same_password_when_adding_a_farm(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'name' => 'Owner',
            'email' => 'owner@example.com',
            'phone' => '+15551234567',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'farmOwner',
            'farm_name' => 'First Farm',
        ])->assertOk();

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Owner',
            'email' => 'owner@example.com',
            'phone' => '+15551234567',
            'password' => 'incorrect123',
            'password_confirmation' => 'incorrect123',
            'role' => 'farmOwner',
            'farm_name' => 'Second Farm',
        ])->assertUnprocessable()->assertJsonValidationErrors('password');

        $this->assertDatabaseCount('farms', 1);
    }

    public function test_login_rejects_invalid_credentials_and_closed_crm_accounts(): void
    {
        $user = User::factory()->create([
            'email' => 'member@example.com',
            'phone' => '+15557654321',
            'password' => bcrypt('password123'),
            'crm_closed_at' => now(),
        ]);

        $this->postJson('/api/v1/auth/login', [
            'identifier' => $user->email,
            'password' => 'password123',
        ])->assertUnprocessable()->assertJsonValidationErrors('identifier');

        $this->postJson('/api/v1/auth/login', [
            'identifier' => '+15557654321',
            'password' => 'wrong-password',
        ])->assertUnprocessable()->assertJsonValidationErrors('identifier');
    }

    public function test_authenticated_user_can_read_me_and_logout_revokes_access_token(): void
    {
        $user = User::factory()->create([
            'role' => 'farmOwner',
            'phone' => '+15550001111',
        ]);
        $farm = Farm::create(['name' => 'Test Farm']);
        $user->farms()->attach($farm);
        Notification::fake();
        $challenge = $this->beginOtpLogin($user->email, 'password');
        $login = $this->verifyOtpLogin($challenge, $user)->assertOk();
        $refresh = RefreshToken::where('user_id', $user->id)->latest('id')->firstOrFail();
        $this->assertTrue($refresh->remember_me);
        $token = $login->json('access_token');
        $refreshToken = $login->json('refresh_token');

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('farms.0.name', 'Test Farm');

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertNoContent();
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
        $this->postJson('/api/v1/auth/refresh', [
            'refresh_token' => $refreshToken,
        ])->assertUnprocessable()->assertJsonValidationErrors('refresh_token');
        $this->assertSame(0, RefreshToken::where('user_id', $user->id)->whereNull('revoked_at')->count());
    }

    public function test_non_remembered_login_uses_short_refresh_token_and_refresh_preserves_policy(): void
    {
        Notification::fake();
        $user = User::factory()->create(['password' => bcrypt('password123')]);
        $challenge = $this->postJson('/api/v1/auth/login', [
            'identifier' => $user->email,
            'password' => 'password123',
            'remember_me' => false,
        ])->assertOk();
        $login = $this->postJson('/api/v1/auth/verify-otp', [
            'challenge_id' => $challenge->json('challenge_id'),
            'code' => $this->otpCode($user),
        ])->assertOk();

        $refresh = RefreshToken::where('user_id', $user->id)->latest('id')->firstOrFail();
        $this->assertFalse($refresh->remember_me);
        $this->assertTrue($refresh->expires_at->isBefore(now()->addHours(2)));

        $refreshed = $this->postJson('/api/v1/auth/refresh', [
            'refresh_token' => $login->json('refresh_token'),
        ])->assertOk();
        $this->assertFalse(RefreshToken::where('user_id', $user->id)->latest('id')->firstOrFail()->remember_me);
        $this->assertNotSame($login->json('refresh_token'), $refreshed->json('refresh_token'));
    }

    public function test_user_can_lookup_legacy_farm_members_collection(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $member = User::factory()->create(['role' => 'farmMember']);
        $farm = Farm::create(['name' => 'Legacy Farm']);

        $owner->farms()->attach($farm);
        $farm->users()->attach($member);

        $members = $owner->farmMembers();

        $this->assertTrue($members->contains(fn (User $user) => $user->id === $owner->id));
        $this->assertTrue($members->contains(fn (User $user) => $user->id === $member->id));
    }

    public function test_seeded_tester_can_login_outside_production(): void
    {
        $this->seed();

        Notification::fake();
        $challenge = $this->beginOtpLogin('test@example.com', 'password');
        $this->verifyOtpLogin($challenge, User::where('email', 'test@example.com')->firstOrFail())
            ->assertOk()->assertJsonPath('user.email', 'test@example.com');
    }

    public function test_production_seed_removes_the_predictable_tester_account(): void
    {
        User::factory()->create(['email' => 'test@example.com']);
        config(['app.env' => 'production']);

        $this->seed();

        $this->assertDatabaseMissing('users', ['email' => 'test@example.com']);
    }

    public function test_login_otp_is_single_use_and_rejects_incorrect_codes(): void
    {
        Notification::fake();
        $user = User::factory()->create(['password' => bcrypt('password123')]);
        $challenge = $this->beginOtpLogin($user->email, 'password123');
        $code = $this->otpCode($user);

        $this->postJson('/api/v1/auth/verify-otp', [
            'challenge_id' => $challenge->json('challenge_id'),
            'code' => '000000',
        ])->assertUnprocessable()->assertJsonValidationErrors('code');

        $this->postJson('/api/v1/auth/verify-otp', [
            'challenge_id' => $challenge->json('challenge_id'),
            'code' => $code,
        ])->assertOk();
        $this->postJson('/api/v1/auth/verify-otp', [
            'challenge_id' => $challenge->json('challenge_id'),
            'code' => $code,
        ])->assertUnprocessable()->assertJsonValidationErrors('code');
    }

    private function beginOtpLogin(string $identifier, string $password): TestResponse
    {
        return $this->postJson('/api/v1/auth/login', [
            'identifier' => $identifier,
            'password' => $password,
            'remember_me' => true,
        ])->assertOk()->assertJsonPath('otp_required', true);
    }

    private function verifyOtpLogin(TestResponse $challenge, User $user): TestResponse
    {
        return $this->postJson('/api/v1/auth/verify-otp', [
            'challenge_id' => $challenge->json('challenge_id'),
            'code' => $this->otpCode($user),
        ]);
    }

    private function otpCode(User $user): string
    {
        $code = null;
        Notification::assertSentTo($user, LoginOtpNotification::class, function (LoginOtpNotification $notification) use (&$code, $user): bool {
            $code = $notification->toMail($user)->introLines[1] ?? null;

            return is_string($code) && preg_match('/^\d{6}$/', $code) === 1;
        });

        return $code;
    }
}
