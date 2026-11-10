<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FarmJoinRequestApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_worker_can_request_a_farm_and_owner_can_accept_it(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Green Valley']);
        $owner->farms()->attach($farm);

        Sanctum::actingAs($worker);
        $request = $this->postJson('/api/v1/farm-join-requests', [
            'invite_code' => $farm->invite_code,
            'message' => 'I would like to help with herd care.',
        ]);

        $request->assertCreated()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.requestedRole', 'farmWorker');
        $requestId = $request->json('data.id');

        Sanctum::actingAs($owner);
        $this->getJson("/api/v1/farms/{$farm->id}/join-requests")
            ->assertOk()
            ->assertJsonPath('data.0.userId', (string) $worker->id);

        $this->patchJson("/api/v1/farms/{$farm->id}/join-requests/{$requestId}", [
            'action' => 'accept',
        ])->assertOk()->assertJsonPath('data.status', 'accepted');

        $this->assertDatabaseHas('farm_user', [
            'farm_id' => $farm->id,
            'user_id' => $worker->id,
        ]);
    }

    public function test_manager_can_register_without_a_farm(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'name' => 'New Manager',
            'email' => 'manager@example.com',
            'phone' => '+15550000001',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'farmManager',
        ])->assertOk()->assertJsonCount(0, 'farms');
    }
}
