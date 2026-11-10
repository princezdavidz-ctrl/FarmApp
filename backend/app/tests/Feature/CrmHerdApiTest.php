<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CrmHerdApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_herd_search_returns_image_and_animal_profile_for_accessible_farms(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Green Valley Farm', 'location' => 'Nakuru']);
        $farm->users()->attach($owner);
        $otherFarm = Farm::create(['name' => 'Green Valley East']);
        $otherFarm->users()->attach(User::factory()->create(['role' => 'farmOwner']));
        $farm->animals()->create([
            'created_by' => $owner->id,
            'tag' => 'SOW-001',
            'name' => 'Daisy',
            'type' => 'sow',
            'sex' => 'female',
            'status' => 'active',
            'birth_date' => '2023-04-12',
            'weight_kg' => 125.5,
            'is_pregnant' => true,
            'last_dewormed_at' => '2026-09-01',
            'last_vaccinated_at' => '2026-08-15',
            'image_path' => 'animal-images/'.$farm->id.'/daisy.jpg',
        ]);

        $this->actingAs($owner, 'sanctum')
            ->getJson('/api/v1/crm/operations/herd?search=Green%20Valley')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', (string) $farm->id)
            ->assertJsonPath('data.0.name', 'Green Valley Farm')
            ->assertJsonPath('data.0.animals.0.name', 'Daisy')
            ->assertJsonPath('data.0.animals.0.tag', 'SOW-001')
            ->assertJsonPath('data.0.animals.0.sex', 'female')
            ->assertJsonPath('data.0.animals.0.birth_date', '2023-04-12')
            ->assertJsonPath('data.0.animals.0.weight_kg', 125.5)
            ->assertJsonPath('data.0.animals.0.is_pregnant', true)
            ->assertJsonPath('data.0.animals.0.last_dewormed_at', '2026-09-01')
            ->assertJsonPath('data.0.animals.0.last_vaccinated_at', '2026-08-15')
            ->assertJsonPath(
                'data.0.animals.0.image_url',
                Storage::disk('public')->url('animal-images/'.$farm->id.'/daisy.jpg'),
            );
    }

    public function test_farm_herd_search_only_returns_farms_the_user_can_manage(): void
    {
        $manager = User::factory()->create(['role' => 'farmManager']);
        $allowedFarm = Farm::create(['name' => 'Allowed Farm']);
        $allowedFarm->users()->attach($manager);
        $restrictedFarm = Farm::create(['name' => 'Restricted Farm']);
        $restrictedFarm->users()->attach($manager, ['permissions' => json_encode(['manageFeed'])]);

        $this->actingAs($manager, 'sanctum')
            ->getJson('/api/v1/crm/operations/herd?search=Farm')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Allowed Farm');
    }

    public function test_farm_herd_search_requires_a_usable_farm_name(): void
    {
        $user = User::factory()->create(['role' => 'farmOwner']);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/crm/operations/herd?search=a')
            ->assertUnprocessable()
            ->assertJsonValidationErrors('search');
    }
}
