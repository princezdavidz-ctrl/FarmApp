<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CrmMemberApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_crm_directory_displays_all_users_in_the_selected_farm(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner']);
        $crmUser = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'finance']);
        $farmUser = User::factory()->create(['role' => 'farmWorker', 'crm_role' => null]);
        $farm = Farm::create(['name' => 'Directory Farm']);
        $farm->users()->attach([$admin->id, $crmUser->id, $farmUser->id]);

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson("/api/v1/crm/members?farm_id={$farm->id}")
            ->assertOk();

        $response->assertJsonCount(3, 'data')
            ->assertJsonFragment(['email' => $crmUser->email])
            ->assertJsonFragment(['email' => $farmUser->email]);
    }
}