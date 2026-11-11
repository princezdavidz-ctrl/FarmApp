<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CropCycleProfitabilityApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_crop_cycle_summary_calculates_cost_revenue_profit_and_yield_per_acre(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Harvest farm', 'farming_type' => 'crops']);
        $farm->users()->attach($owner->id);
        $cycle = $farm->cropCycles()->create([
            'plot_name' => 'North field',
            'crop_name' => 'Maize',
            'area_acres' => 2,
            'planting_date' => '2026-03-01',
            'actual_harvest_date' => '2026-07-01',
            'actual_yield_kg' => 3000,
            'actual_revenue_kes' => 180000,
            'status' => 'harvested',
        ]);
        $farm->cropActivities()->create([
            'crop_cycle_id' => $cycle->id,
            'activity_type' => 'fertilizer',
            'activity_date' => '2026-03-10',
            'title' => 'Basal fertilizer',
            'cost' => 12000,
        ]);
        $farm->cropActivities()->create([
            'crop_cycle_id' => $cycle->id,
            'activity_type' => 'pesticide',
            'activity_date' => '2026-04-10',
            'title' => 'Pest control',
            'cost' => 3000,
        ]);
        $farm->cropActivities()->create([
            'activity_type' => 'irrigation',
            'activity_date' => '2026-04-12',
            'title' => 'Shared field irrigation',
            'cost' => 5000,
        ]);

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/crop-cycles")
            ->assertOk()
            ->assertJsonPath('data.0.activity_cost_kes', 15000)
            ->assertJsonPath('data.0.gross_profit_kes', 165000)
            ->assertJsonPath('data.0.yield_kg_per_acre', 1500);
    }

    public function test_harvest_revenue_must_be_non_negative(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Validation farm']);
        $farm->users()->attach($owner->id);
        $cycle = $farm->cropCycles()->create([
            'plot_name' => 'Plot A',
            'crop_name' => 'Beans',
            'area_acres' => 1,
            'planting_date' => '2026-02-01',
        ]);

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/crop-cycles/{$cycle->id}", [
                'actual_revenue_kes' => -1,
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('actual_revenue_kes');
    }
}
