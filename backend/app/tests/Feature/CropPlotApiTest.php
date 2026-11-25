<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CropPlotApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_owner_can_create_list_update_and_delete_crop_plots(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Green Valley', 'farming_type' => 'crops']);
        $farm->users()->attach($owner->id);

        $id = $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-plots", [
                'name' => 'North field',
                'area_acres' => 2.5,
                'soil_type' => 'Loam',
                'irrigation_source' => 'Borehole',
                'latitude' => -1.2921,
                'longitude' => 36.8219,
                'status' => 'active',
            ])
            ->assertCreated()
            ->assertJsonPath('data.name', 'North field')
            ->assertJsonPath('data.soil_type', 'Loam')
            ->json('data.id');

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/crop-plots?status=active")
            ->assertOk()
            ->assertJsonFragment(['name' => 'North field']);

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/crop-plots/{$id}", [
                'area_acres' => 3,
                'status' => 'fallow',
            ])
            ->assertOk()
            ->assertJsonPath('data.status', 'fallow')
            ->assertJsonPath('data.area_acres', '3.00');

        $this->actingAs($owner, 'sanctum')
            ->deleteJson("/api/v1/farms/{$farm->id}/crop-plots/{$id}")
            ->assertNoContent();

        $this->assertDatabaseMissing('crop_plots', ['id' => $id]);
    }

    public function test_crop_plots_are_farm_isolated_and_respect_view_and_manage_permissions(): void
    {
        $manager = User::factory()->create(['role' => 'farmManager']);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Mixed farm']);
        $farm->users()->attach([$manager->id, $worker->id]);
        $plot = $farm->cropPlots()->create([
            'name' => 'East field',
            'area_acres' => 1.25,
            'status' => 'active',
        ]);
        $otherFarm = Farm::create(['name' => 'Other farm']);
        $otherFarm->users()->attach($manager->id);

        $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/crop-plots")
            ->assertOk()
            ->assertJsonFragment(['name' => 'East field']);

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-plots", [
                'name' => 'West field',
                'area_acres' => 1,
            ])
            ->assertForbidden();

        $this->actingAs($manager, 'sanctum')
            ->patchJson("/api/v1/farms/{$otherFarm->id}/crop-plots/{$plot->id}", [
                'status' => 'inactive',
            ])
            ->assertNotFound();
    }

    public function test_crop_plot_validation_rejects_invalid_area_coordinates_and_duplicate_names(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Validation farm']);
        $farm->users()->attach($owner->id);
        $farm->cropPlots()->create([
            'name' => 'North field',
            'area_acres' => 1,
        ]);

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-plots", [
                'name' => 'North field',
                'area_acres' => 0,
                'latitude' => 120,
                'longitude' => 200,
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['name', 'area_acres', 'latitude', 'longitude']);
    }
}
