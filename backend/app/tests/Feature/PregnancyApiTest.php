<?php

namespace Tests\Feature;

use App\Models\Animal;
use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PregnancyApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_create_a_pregnancy_with_a_114_day_due_date(): void
    {
        [$user, $farm, $sow] = $this->farmWithSow();

        $response = $this->actingAs($user)->postJson(
            "/api/v1/farms/{$farm->id}/pregnancies",
            [
                'sow_id' => $sow->id,
                'mating_date' => '2026-01-01',
                'semen_used' => 'Large White / batch LW-24',
                'status' => 'confirmed',
            ],
        );

        $response->assertCreated()
            ->assertJsonPath('data.sow_id', (string) $sow->id)
            ->assertJsonPath('data.expected_farrowing_date', '2026-04-25')
            ->assertJsonPath('data.semen_used', 'Large White / batch LW-24')
            ->assertJsonPath('data.status', 'confirmed');
    }

    public function test_owner_can_record_a_farrowing_outcome(): void
    {
        [$user, $farm, $sow] = $this->farmWithSow();
        $pregnancy = $farm->pregnancies()->create([
            'sow_id' => $sow->id,
            'created_by' => $user->id,
            'mating_date' => '2026-01-01',
            'expected_farrowing_date' => '2026-04-25',
            'status' => 'confirmed',
        ]);

        $this->actingAs($user)->patchJson(
            "/api/v1/farms/{$farm->id}/pregnancies/{$pregnancy->id}",
            [
                'status' => 'farrowed',
                'actual_farrowing_date' => '2026-04-24',
                'born_alive' => 10,
                'stillborn' => 1,
                'mummified' => 0,
                'weaned' => 9,
            ],
        )->assertOk()
            ->assertJsonPath('data.status', 'farrowed')
            ->assertJsonPath('data.born_alive', 10);
    }

    public function test_owner_cannot_record_a_male_pig_as_the_sow(): void
    {
        [$user, $farm] = $this->farmWithSow();
        $male = Animal::create([
            'farm_id' => $farm->id,
            'tag' => 'BOAR-1',
            'type' => 'boar',
            'sex' => 'male',
        ]);

        $this->actingAs($user)->postJson(
            "/api/v1/farms/{$farm->id}/pregnancies",
            [
                'sow_id' => $male->id,
                'mating_date' => '2026-01-01',
            ],
        )->assertUnprocessable()
            ->assertJsonValidationErrors(['sow_id']);
    }

    public function test_user_cannot_access_another_farms_pregnancy(): void
    {
        [$user, $farm, $sow] = $this->farmWithSow();
        $otherFarm = Farm::create(['name' => 'Other Farm']);
        $otherSow = Animal::create([
            'farm_id' => $otherFarm->id,
            'tag' => 'OTHER-1',
            'type' => 'sow',
            'sex' => 'female',
        ]);
        $pregnancy = $otherFarm->pregnancies()->create([
            'sow_id' => $otherSow->id,
            'mating_date' => '2026-01-01',
            'expected_farrowing_date' => '2026-04-25',
        ]);

        $this->actingAs($user)->getJson(
            "/api/v1/farms/{$farm->id}/pregnancies/{$pregnancy->id}",
        )->assertNotFound();
    }

    /** @return array{User, Farm, Animal} */
    private function farmWithSow(): array
    {
        $user = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Test Farm']);
        $user->farms()->attach($farm);
        $sow = Animal::create([
            'farm_id' => $farm->id,
            'tag' => 'SOW-1',
            'type' => 'sow',
            'sex' => 'female',
        ]);

        return [$user, $farm, $sow];
    }
}