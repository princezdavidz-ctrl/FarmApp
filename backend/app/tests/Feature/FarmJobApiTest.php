<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\FarmJobPosting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FarmJobApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_owner_can_post_a_role_and_accepting_a_matching_application_joins_the_staff_member(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::factory()->create(['created_by' => $owner->id]);
        $owner->farms()->attach($farm);
        $posting = $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/job-postings", [
                'role' => 'farmWorker',
                'title' => 'Livestock attendant',
                'description' => 'Care for livestock and maintain the pens.',
                'location' => 'Nakuru',
            ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'open');
        $postingId = $posting->json('data.id');

        $worker = User::factory()->create(['role' => 'farmWorker']);
        $this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/farm-jobs')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.title', 'Livestock attendant');
        $application = $this->postJson("/api/v1/farm-jobs/{$postingId}/applications", [
            'message' => 'I have livestock experience.',
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending');

        $this->actingAs($owner, 'sanctum')
            ->patchJson(
                "/api/v1/farms/{$farm->id}/job-postings/{$postingId}/applications/{$application->json('data.id')}",
                ['status' => 'accepted'],
            )
            ->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        $this->assertDatabaseHas('farm_user', [
            'farm_id' => $farm->id,
            'user_id' => $worker->id,
            'role' => 'farmWorker',
        ]);
        $this->assertDatabaseHas('farm_job_postings', [
            'id' => $postingId,
            'status' => 'closed',
        ]);
    }

    public function test_staff_cannot_apply_to_another_role_or_farm_owner_can_manage_only_their_farm(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::factory()->create(['created_by' => $owner->id]);
        $owner->farms()->attach($farm);
        $posting = FarmJobPosting::create([
            'farm_id' => $farm->id,
            'created_by' => $owner->id,
            'role' => 'farmManager',
            'title' => 'Farm manager',
            'description' => 'Manage farm operations.',
            'status' => 'open',
        ]);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/farm-jobs/{$posting->id}/applications")
            ->assertForbidden();

        $otherOwner = User::factory()->create(['role' => 'farmOwner']);
        $this->actingAs($otherOwner, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/job-postings")
            ->assertForbidden();
    }
}
