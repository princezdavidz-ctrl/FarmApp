<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FeedFormulationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_feed_manager_can_save_and_view_a_calculated_formulation(): void
    {
        $user = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Formulation farm']);
        $farm->users()->attach($user->id);

        $payload = [
            'name' => 'Grower ration',
            'target_species' => 'pigs',
            'batch_size_kg' => 100,
            'notes' => 'Use clean, dry ingredients.',
            'ingredients' => [
                ['name' => 'Maize meal', 'inclusion_percent' => 60, 'crude_protein_percent' => 9, 'energy_mj_per_kg' => 13.5, 'cost_per_kg' => 55],
                ['name' => 'Soybean meal', 'inclusion_percent' => 30, 'crude_protein_percent' => 44, 'energy_mj_per_kg' => 12.5, 'cost_per_kg' => 110],
                ['name' => 'Wheat bran', 'inclusion_percent' => 10, 'crude_protein_percent' => 16, 'energy_mj_per_kg' => 10, 'cost_per_kg' => 35],
            ],
        ];

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/feed/formulations", $payload)
            ->assertCreated()
            ->assertJsonPath('data.name', 'Grower ration')
            ->assertJsonPath('data.estimated_crude_protein_percent', 20.6)
            ->assertJsonPath('data.estimated_energy_mj_per_kg', 12.95)
            ->assertJsonPath('data.estimated_cost_per_kg', 70.5)
            ->assertJsonPath('data.ingredients.0.batch_quantity_kg', 60);

        $this->actingAs($user, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/feed/formulations")
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_formulation_requires_inclusion_percentages_to_total_one_hundred(): void
    {
        $user = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Formulation farm']);
        $farm->users()->attach($user->id);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/feed/formulations", [
                'name' => 'Invalid ration',
                'target_species' => 'pigs',
                'batch_size_kg' => 50,
                'ingredients' => [
                    ['name' => 'Maize', 'inclusion_percent' => 60],
                    ['name' => 'Soy', 'inclusion_percent' => 30],
                ],
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('ingredients');

        $this->assertDatabaseCount('feed_formulations', 0);
    }

    public function test_formulation_cannot_be_deleted_through_another_farm(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $otherOwner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'First farm']);
        $otherFarm = Farm::create(['name' => 'Second farm']);
        $farm->users()->attach($owner->id);
        $otherFarm->users()->attach($otherOwner->id);

        $response = $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/feed/formulations", [
                'name' => 'Starter ration',
                'target_species' => 'pigs',
                'batch_size_kg' => 20,
                'ingredients' => [
                    ['name' => 'Maize', 'inclusion_percent' => 70],
                    ['name' => 'Soy', 'inclusion_percent' => 30],
                ],
            ])
            ->assertCreated();

        $id = $response->json('data.id');

        $this->actingAs($otherOwner, 'sanctum')
            ->deleteJson("/api/v1/farms/{$otherFarm->id}/feed/formulations/{$id}")
            ->assertNotFound();

        $this->assertDatabaseHas('feed_formulations', ['id' => $id, 'farm_id' => $farm->id]);
    }
}
