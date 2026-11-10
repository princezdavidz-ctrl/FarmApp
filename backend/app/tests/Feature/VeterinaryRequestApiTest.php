<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use App\Models\VeterinarianProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class VeterinaryRequestApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_can_request_a_veterinarian_and_matching_vet_can_accept_and_complete(): void
    {
        $farmer = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::factory()->create(['created_by' => $farmer->id]);
        $farmer->farms()->attach($farm);
        $request = $this->actingAs($farmer, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/veterinary-requests", [
                'county' => 'Nairobi',
                'animal_type' => 'Poultry',
                'animal_name' => 'Layer flock',
                'issue_description' => 'Several birds are lethargic and not eating.',
                'location' => 'Westlands, Nairobi',
                'latitude' => -1.26,
                'longitude' => 36.8,
            ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'open');
        $requestId = $request->json('data.id');

        $vetUser = User::factory()->create(['role' => 'veterinarian']);
        VeterinarianProfile::create([
            'user_id' => $vetUser->id,
            'reference' => fake()->uuid(),
            'license_number' => 'VET-'.fake()->unique()->numerify('#####'),
            'clinic_name' => 'Nairobi Animal Care',
            'county' => 'Nairobi',
            'specialization' => 'Poultry',
            'years_experience' => 5,
            'status' => 'approved',
            'subscription_expires_at' => now()->addDays(30),
        ]);

        $this->actingAs($vetUser, 'sanctum')
            ->getJson('/api/v1/veterinarians/requests')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.animal_type', 'Poultry')
            ->assertJsonPath('data.0.farm_name', $farm->name);
        $this->postJson("/api/v1/veterinarians/requests/{$requestId}/accept")
            ->assertOk()
            ->assertJsonPath('data.status', 'accepted');
        $this->postJson("/api/v1/veterinary-requests/{$requestId}/status", [
            'status' => 'completed',
        ])->assertOk()->assertJsonPath('data.status', 'completed');
        $this->actingAs($farmer, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/veterinary-requests")
            ->assertOk()
            ->assertJsonPath('data.0.status', 'completed');
    }

    public function test_veterinarian_request_cannot_be_seen_or_claimed_outside_the_vet_county(): void
    {
        $farmer = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::factory()->create(['created_by' => $farmer->id]);
        $farmer->farms()->attach($farm);
        $request = $this->actingAs($farmer, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/veterinary-requests", [
                'county' => 'Nairobi',
                'animal_type' => 'Dairy cattle',
                'issue_description' => 'Needs a checkup.',
                'location' => 'Westlands, Nairobi',
            ])
            ->assertCreated();

        $vetUser = User::factory()->create(['role' => 'veterinarian']);
        VeterinarianProfile::create([
            'user_id' => $vetUser->id,
            'reference' => fake()->uuid(),
            'license_number' => 'VET-'.fake()->unique()->numerify('#####'),
            'clinic_name' => 'Mombasa Animal Care',
            'county' => 'Mombasa',
            'specialization' => 'Livestock',
            'years_experience' => 5,
            'status' => 'approved',
            'subscription_expires_at' => now()->addDays(30),
        ]);

        $this->actingAs($vetUser, 'sanctum')
            ->getJson('/api/v1/veterinarians/requests')
            ->assertOk()
            ->assertJsonCount(0, 'data');
        $this->postJson("/api/v1/veterinarians/requests/{$request->json('data.id')}/accept")
            ->assertStatus(409);
    }
}
