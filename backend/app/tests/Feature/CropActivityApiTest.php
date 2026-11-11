<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CropActivityApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_owner_can_record_list_update_and_delete_crop_activities(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Green Valley', 'farming_type' => 'crops']);
        $farm->users()->attach($owner->id);
        $cycle = $farm->cropCycles()->create([
            'plot_name' => 'North field',
            'crop_name' => 'Maize',
            'area_acres' => 2,
            'planting_date' => '2026-03-01',
            'status' => 'growing',
        ]);

        $id = $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-activities", [
                'crop_cycle_id' => $cycle->id,
                'activity_type' => 'fertilizer',
                'activity_date' => '2026-04-01',
                'title' => 'Top dressing',
                'product_name' => 'CAN',
                'quantity' => 50,
                'unit' => 'kg',
                'cost' => 4200,
            ])
            ->assertCreated()
            ->assertJsonPath('data.activity_type', 'fertilizer')
            ->assertJsonPath('data.crop_cycle_id', $cycle->id)
            ->json('data.id');

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/crop-activities?activity_type=fertilizer")
            ->assertOk()
            ->assertJsonFragment(['title' => 'Top dressing']);

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/crop-activities/{$id}", [
                'cost' => 4500,
                'notes' => 'Applied after rainfall.',
            ])
            ->assertOk()
            ->assertJsonPath('data.cost', '4500.00');

        $this->actingAs($owner, 'sanctum')
            ->deleteJson("/api/v1/farms/{$farm->id}/crop-activities/{$id}")
            ->assertNoContent();

        $this->assertDatabaseMissing('crop_activities', ['id' => $id]);
    }

    public function test_crop_activity_requires_manage_permission_and_same_farm_crop_cycle(): void
    {
        $manager = User::factory()->create(['role' => 'farmManager']);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Mixed farm']);
        $farm->users()->attach([$manager->id, $worker->id]);
        $otherFarm = Farm::create(['name' => 'Other farm']);
        $otherFarm->users()->attach($manager->id);
        $otherCycle = $otherFarm->cropCycles()->create([
            'plot_name' => 'Other plot',
            'crop_name' => 'Beans',
            'area_acres' => 1,
            'planting_date' => '2026-02-01',
        ]);

        $payload = [
            'crop_cycle_id' => $otherCycle->id,
            'activity_type' => 'irrigation',
            'activity_date' => '2026-04-01',
            'title' => 'Watering',
        ];

        $this->actingAs($manager, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-activities", $payload)
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['crop_cycle_id']);

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-activities", [
                'activity_type' => 'irrigation',
                'activity_date' => '2026-04-01',
                'title' => 'Watering',
            ])
            ->assertForbidden();
    }

    public function test_crop_activity_validation_rejects_invalid_quantity_and_type(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Validation farm']);
        $farm->users()->attach($owner->id);

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/crop-activities", [
                'activity_type' => 'unknown',
                'activity_date' => '2026-04-01',
                'title' => 'Treatment',
                'quantity' => 0,
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['activity_type', 'quantity']);
    }
}
