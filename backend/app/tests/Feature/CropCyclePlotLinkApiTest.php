<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CropCyclePlotLinkApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_crop_cycle_can_be_created_and_returned_with_a_plot_from_the_same_farm(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Linked farm', 'farming_type' => 'crops']);
        $farm->users()->attach($owner->id);
        $plot = $farm->cropPlots()->create([
            'name' => 'North field',
            'area_acres' => 4.5,
            'status' => 'active',
        ]);

        $id = $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-cycles", [
                'crop_plot_id' => $plot->id,
                'crop_name' => 'Maize',
                'area_acres' => 2.5,
                'planting_date' => '2026-03-01',
            ])
            ->assertCreated()
            ->assertJsonPath('data.crop_plot_id', $plot->id)
            ->assertJsonPath('data.plot_name', 'North field')
            ->assertJsonPath('data.crop_plot.name', 'North field')
            ->json('data.id');

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/crop-cycles")
            ->assertOk()
            ->assertJsonPath('data.0.crop_plot.id', $plot->id);

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/crop-cycles/{$id}", [
                'crop_plot_id' => null,
                'plot_name' => 'Legacy detached field',
            ])
            ->assertOk()
            ->assertJsonPath('data.crop_plot_id', null)
            ->assertJsonPath('data.plot_name', 'Legacy detached field');
    }

    public function test_crop_cycle_cannot_link_to_a_plot_owned_by_another_farm(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Farm A']);
        $otherFarm = Farm::create(['name' => 'Farm B']);
        $farm->users()->attach($owner->id);
        $otherPlot = $otherFarm->cropPlots()->create([
            'name' => 'Other farm plot',
            'area_acres' => 2,
        ]);

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-cycles", [
                'crop_plot_id' => $otherPlot->id,
                'crop_name' => 'Beans',
                'area_acres' => 1,
                'planting_date' => '2026-03-01',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['crop_plot_id']);
    }

    public function test_deleting_a_plot_preserves_its_crop_cycle_and_legacy_plot_name(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Delete plot farm']);
        $farm->users()->attach($owner->id);
        $plot = $farm->cropPlots()->create([
            'name' => 'South field',
            'area_acres' => 3,
        ]);
        $cycle = $farm->cropCycles()->create([
            'crop_plot_id' => $plot->id,
            'plot_name' => $plot->name,
            'crop_name' => 'Beans',
            'area_acres' => 1.5,
            'planting_date' => '2026-03-01',
        ]);

        $plot->delete();

        $this->assertDatabaseHas('crop_cycles', [
            'id' => $cycle->id,
            'crop_plot_id' => null,
            'plot_name' => 'South field',
        ]);
    }
}
