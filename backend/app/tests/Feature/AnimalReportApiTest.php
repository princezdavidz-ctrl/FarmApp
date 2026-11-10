<?php

namespace Tests\Feature;

use App\Models\Animal;
use App\Models\Farm;
use App\Models\GrowthRecord;
use App\Models\HealthRecord;
use App\Models\Pregnancy;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AnimalReportApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_report_returns_only_selected_animals_records_in_date_range(): void
    {
        [$user, $farm, $pig] = $this->farmWithOwnerAndPig();
        $otherPig = $farm->animals()->create([
            'tag' => 'PIG-OTHER',
            'type' => 'grower',
            'sex' => 'female',
        ]);

        $healthRecord = HealthRecord::create([
            'farm_id' => $farm->id,
            'animal_id' => $pig->id,
            'type' => 'vaccination',
            'status' => 'completed',
            'visit_date' => '2026-09-15 09:00:00',
        ]);
        HealthRecord::create([
            'farm_id' => $farm->id,
            'animal_id' => $pig->id,
            'type' => 'treatment',
            'status' => 'recovering',
            'visit_date' => '2026-08-15 09:00:00',
        ]);
        HealthRecord::create([
            'farm_id' => $farm->id,
            'animal_id' => $otherPig->id,
            'type' => 'treatment',
            'status' => 'recovering',
            'visit_date' => '2026-09-15 09:00:00',
        ]);
        $growthRecord = GrowthRecord::create([
            'farm_id' => $farm->id,
            'animal_id' => $pig->id,
            'current_weight' => 42.5,
            'measurement_date' => '2026-09-20 09:00:00',
        ]);
        $pregnancy = Pregnancy::create([
            'farm_id' => $farm->id,
            'sow_id' => $pig->id,
            'mating_date' => '2026-09-05',
            'expected_farrowing_date' => '2026-12-28',
            'status' => 'confirmed',
        ]);
        $duePregnancy = Pregnancy::create([
            'farm_id' => $farm->id,
            'sow_id' => $pig->id,
            'mating_date' => '2026-08-01',
            'expected_farrowing_date' => '2026-09-28',
            'status' => 'confirmed',
        ]);

        $this->actingAs($user)
            ->getJson("/api/v1/farms/{$farm->id}/animals/{$pig->id}/report?startDate=2026-09-01&endDate=2026-09-30")
            ->assertOk()
            ->assertJsonPath('data.animal.id', (string) $pig->id)
            ->assertJsonPath('data.animal.tag', $pig->tag)
            ->assertJsonPath('data.healthRecords.0.id', (string) $healthRecord->id)
            ->assertJsonCount(1, 'data.healthRecords')
            ->assertJsonPath('data.growthRecords.0.id', (string) $growthRecord->id)
            ->assertJsonCount(1, 'data.growthRecords')
            ->assertJsonCount(2, 'data.pregnancies')
            ->assertJsonFragment(['id' => (string) $pregnancy->id])
            ->assertJsonFragment(['id' => (string) $duePregnancy->id])
            ->assertJsonPath('data.period.startDate', '2026-09-01T00:00:00+00:00')
            ->assertJsonPath('data.period.endDate', '2026-09-30T23:59:59+00:00');
    }

    public function test_report_is_empty_for_an_animal_without_history(): void
    {
        [$user, $farm, $pig] = $this->farmWithOwnerAndPig();

        $this->actingAs($user)
            ->getJson("/api/v1/farms/{$farm->id}/animals/{$pig->id}/report?dateRange=year")
            ->assertOk()
            ->assertJsonCount(0, 'data.healthRecords')
            ->assertJsonCount(0, 'data.growthRecords')
            ->assertJsonCount(0, 'data.pregnancies');
    }

    public function test_report_does_not_expose_an_animal_from_another_farm(): void
    {
        [$user, $farm] = $this->farmWithOwnerAndPig();
        $otherFarm = Farm::create(['name' => 'Other farm']);
        $otherPig = $otherFarm->animals()->create([
            'tag' => 'OTHER-1',
            'type' => 'sow',
            'sex' => 'female',
        ]);

        $this->actingAs($user)
            ->getJson("/api/v1/farms/{$farm->id}/animals/{$otherPig->id}/report")
            ->assertNotFound();
    }

    public function test_report_requires_view_reports_permission_for_non_owners(): void
    {
        $user = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Test farm']);
        $farm->users()->attach($user, ['permissions' => json_encode(['manageHerd'])]);
        $pig = $farm->animals()->create([
            'tag' => 'WORKER-1',
            'type' => 'grower',
            'sex' => 'female',
        ]);

        $this->actingAs($user)
            ->getJson("/api/v1/farms/{$farm->id}/animals/{$pig->id}/report")
            ->assertForbidden();
    }

    /** @return array{User, Farm, Animal} */
    private function farmWithOwnerAndPig(): array
    {
        $user = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Test farm']);
        $farm->users()->attach($user);
        $pig = $farm->animals()->create([
            'tag' => 'PIG-1',
            'type' => 'sow',
            'sex' => 'female',
        ]);

        return [$user, $farm, $pig];
    }
}