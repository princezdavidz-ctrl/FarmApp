<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FarmMemberApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_owner_can_remove_a_non_owner_member(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $member = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Member removal farm']);
        $farm->users()->attach([$owner->id, $member->id]);

        $this->actingAs($owner, 'sanctum')
            ->deleteJson("/api/v1/farms/{$farm->id}/members/{$member->id}")
            ->assertOk()
            ->assertJsonPath('message', 'Farm member removed.');

        $this->assertDatabaseMissing('farm_user', [
            'farm_id' => $farm->id,
            'user_id' => $member->id,
        ]);
    }

    public function test_only_the_farm_owner_can_remove_members_and_an_owner_cannot_be_removed(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $manager = User::factory()->create(['role' => 'farmManager']);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Protected member farm']);
        $farm->users()->attach([$owner->id, $manager->id, $worker->id]);

        $this->actingAs($manager, 'sanctum')
            ->deleteJson("/api/v1/farms/{$farm->id}/members/{$worker->id}")
            ->assertForbidden();

        $this->actingAs($owner, 'sanctum')
            ->deleteJson("/api/v1/farms/{$farm->id}/members/{$owner->id}")
            ->assertNotFound();

        $this->assertDatabaseHas('farm_user', [
            'farm_id' => $farm->id,
            'user_id' => $worker->id,
        ]);
    }
}
