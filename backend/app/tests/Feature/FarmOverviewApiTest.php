<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FarmOverviewApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_overview_includes_crop_activity_metrics(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Mixed farm', 'farming_type' => 'mixed']);
        $farm->users()->attach($owner->id);

        $farm->cropCycles()->create([
            'plot_name' => 'North field',
            'crop_name' => 'Maize',
            'area_acres' => 2.5,
            'planting_date' => now()->subDays(20)->toDateString(),
            'expected_harvest_date' => now()->addDays(10)->toDateString(),
            'status' => 'growing',
        ]);
        $farm->cropCycles()->create([
            'plot_name' => 'Kitchen garden',
            'crop_name' => 'Kale',
            'area_acres' => 0.5,
            'planting_date' => now()->subDays(80)->toDateString(),
            'status' => 'harvested',
        ]);

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/overview")
            ->assertOk()
            ->assertJsonPath('active_crop_cycles', 1)
            ->assertJsonPath('crop_cycles_count', 2)
            ->assertJsonPath('crop_area_acres', 2.5)
            ->assertJsonPath('upcoming_harvest_count', 1);
    }
}
