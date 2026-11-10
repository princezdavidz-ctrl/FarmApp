<?php

namespace Tests\Feature;

use App\Models\PushDevice;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PushDeviceApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_register_and_remove_a_push_device(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $token = 'test-fcm-device-token';

        $this->postJson('/api/v1/auth/push-token', [
            'token' => $token,
            'platform' => 'android',
        ])->assertOk();

        $this->assertDatabaseHas('push_devices', [
            'user_id' => $user->id,
            'token_hash' => hash('sha256', $token),
            'platform' => 'android',
        ]);

        $this->postJson('/api/v1/auth/push-token', [
            'token' => $token,
            'platform' => 'ios',
        ])->assertOk();
        $this->assertSame(1, PushDevice::query()->count());
        $this->assertDatabaseHas('push_devices', [
            'user_id' => $user->id,
            'token_hash' => hash('sha256', $token),
            'platform' => 'ios',
        ]);

        $this->deleteJson('/api/v1/auth/push-token', ['token' => $token])
            ->assertOk();
        $this->assertDatabaseMissing('push_devices', [
            'token_hash' => hash('sha256', $token),
        ]);
    }

    public function test_user_cannot_remove_another_users_push_device(): void
    {
        $owner = User::factory()->create();
        $otherUser = User::factory()->create();
        $token = 'private-fcm-device-token';
        PushDevice::create([
            'user_id' => $owner->id,
            'token' => $token,
            'token_hash' => hash('sha256', $token),
            'platform' => 'ios',
        ]);
        Sanctum::actingAs($otherUser);

        $this->deleteJson('/api/v1/auth/push-token', ['token' => $token])
            ->assertOk();
        $this->assertDatabaseHas('push_devices', [
            'user_id' => $owner->id,
            'token_hash' => hash('sha256', $token),
        ]);
    }
}
