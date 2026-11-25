<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SoilTestApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_owner_can_create_list_update_and_delete_soil_tests_for_a_plot(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Soil test farm']);
        $farm->users()->attach($owner->id);
        $plot = $farm->cropPlots()->create(['name' => 'North field', 'area_acres' => 2]);

        $id = $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-plots/{$plot->id}/soil-tests", [
                'sampled_at' => '2026-11-20',
                'laboratory_name' => 'County Soil Lab',
                'ph' => 6.4,
                'nitrogen_ppm' => 28,
                'phosphorus_ppm' => 14,
                'potassium_ppm' => 110,
                'organic_matter_percent' => 3.2,
            ])
            ->assertCreated()
            ->assertJsonPath('data.ph', '6.40')
            ->json('data.id');

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/crop-plots/{$plot->id}/soil-tests")
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/crop-plots/{$plot->id}/soil-tests/{$id}", [
                'sampled_at' => '2026-11-21',
                'ph' => 6.8,
            ])
            ->assertOk()
            ->assertJsonPath('data.ph', '6.80');

        $this->actingAs($owner, 'sanctum')
            ->deleteJson("/api/v1/farms/{$farm->id}/crop-plots/{$plot->id}/soil-tests/{$id}")
            ->assertNoContent();
    }

    public function test_soil_tests_enforce_farm_isolation_and_input_ranges(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Farm A']);
        $farm->users()->attach($owner->id);
        $plot = $farm->cropPlots()->create(['name' => 'Plot A', 'area_acres' => 1]);
        $otherFarm = Farm::create(['name' => 'Farm B']);
        $otherPlot = $otherFarm->cropPlots()->create(['name' => 'Plot B', 'area_acres' => 1]);

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-plots/{$plot->id}/soil-tests", [
                'sampled_at' => '2026-11-20',
                'ph' => 15,
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['ph']);

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/crop-plots/{$otherPlot->id}/soil-tests")
            ->assertNotFound();
    }
}
