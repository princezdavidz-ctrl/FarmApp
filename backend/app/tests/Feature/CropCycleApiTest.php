<?php

namespace Tests\Feature;

use App\Models\CropCycle;
use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CropCycleApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_owner_can_create_list_update_and_delete_crop_cycles(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Green Valley', 'farming_type' => 'crops']);
        $farm->users()->attach($owner->id);

        $id = $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-cycles", [
                'plot_name' => 'North field',
                'crop_name' => 'Maize',
                'variety' => 'H6213',
                'area_acres' => 2.5,
                'planting_date' => '2026-03-01',
                'expected_harvest_date' => '2026-07-15',
                'expected_yield_kg' => 3200,
                'status' => 'planted',
            ])
            ->assertCreated()
            ->assertJsonPath('data.crop_name', 'Maize')
            ->assertJsonPath('data.status', 'planted')
            ->json('data.id');

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/crop-cycles")
            ->assertOk()
            ->assertJsonFragment(['plot_name' => 'North field']);

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/crop-cycles/{$id}", [
                'status' => 'growing',
            ])
            ->assertOk()
            ->assertJsonPath('data.status', 'growing');

        $this->actingAs($owner, 'sanctum')
            ->deleteJson("/api/v1/farms/{$farm->id}/crop-cycles/{$id}")
            ->assertNoContent();

        $this->assertDatabaseMissing('crop_cycles', ['id' => $id]);
    }

    public function test_crop_cycles_are_isolated_by_farm_and_require_permissions(): void
    {
        $manager = User::factory()->create(['role' => 'farmManager']);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Mixed farm', 'farming_type' => 'mixed']);
        $farm->users()->attach([$manager->id, $worker->id]);
        $cycle = $farm->cropCycles()->create([
            'plot_name' => 'East field',
            'crop_name' => 'Beans',
            'area_acres' => 1.25,
            'planting_date' => '2026-02-01',
            'status' => 'growing',
        ]);
        $otherFarm = Farm::create(['name' => 'Other farm']);
        $otherFarm->users()->attach($manager->id);

        $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/crop-cycles")
            ->assertOk()
            ->assertJsonFragment(['crop_name' => 'Beans']);

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-cycles", [
                'plot_name' => 'West field',
                'crop_name' => 'Potatoes',
                'area_acres' => 1,
                'planting_date' => '2026-02-05',
            ])
            ->assertForbidden();

        $this->actingAs($manager, 'sanctum')
            ->patchJson("/api/v1/farms/{$otherFarm->id}/crop-cycles/{$cycle->id}", [
                'status' => 'harvested',
            ])
            ->assertNotFound();
    }

    public function test_crop_cycle_validation_rejects_invalid_dates_and_area(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Validation farm']);
        $farm->users()->attach($owner->id);

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-cycles", [
                'plot_name' => 'Plot A',
                'crop_name' => 'Maize',
                'area_acres' => 0,
                'planting_date' => '2026-07-01',
                'expected_harvest_date' => '2026-06-01',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['area_acres', 'expected_harvest_date']);
    }
}
