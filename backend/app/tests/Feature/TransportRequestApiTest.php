<?php

namespace Tests\Feature;

use App\Models\DriverProfile;
use App\Models\Farm;
use App\Models\SupplierProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TransportRequestApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_seller_can_request_a_matching_online_driver_and_only_one_driver_can_accept(): void
    {
        $seller = User::factory()->create();
        $farm = Farm::factory()->create(['created_by' => $seller->id]);
        $seller->farms()->attach($farm);
        $request = $this->actingAs($seller, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/transport-requests", $this->requestData())
            ->assertCreated()
            ->assertJsonPath('data.status', 'open');
        $requestId = $request->json('data.id');

        $nearbyDriver = $this->createDriver('Livestock lorry', true, -1.2864, 36.8172);
        $wrongVehicleDriver = $this->createDriver('Pickup', true, -1.2864, 36.8172);
        $offlineDriver = $this->createDriver('Livestock lorry', false, -1.2864, 36.8172);
        $farDriver = $this->createDriver('Livestock lorry', true, -3.0, 38.0);

        $this->actingAs($nearbyDriver->user, 'sanctum')
            ->getJson('/api/v1/animal-drivers/requests')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $requestId)
            ->assertJsonPath('data.0.vehicle_type', 'Livestock lorry');

        foreach ([$wrongVehicleDriver, $farDriver] as $driver) {
            $this->actingAs($driver->user, 'sanctum')
                ->getJson('/api/v1/animal-drivers/requests')
                ->assertOk()
                ->assertJsonCount(0, 'data');
        }
        $this->actingAs($offlineDriver->user, 'sanctum')
            ->getJson('/api/v1/animal-drivers/requests')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->actingAs($nearbyDriver->user, 'sanctum')
            ->postJson("/api/v1/animal-drivers/requests/{$requestId}/accept")
            ->assertOk()
            ->assertJsonPath('data.status', 'accepted')
            ->assertJsonPath('data.driver_profile_id', (string) $nearbyDriver->id);
        $this->actingAs($wrongVehicleDriver->user, 'sanctum')
            ->postJson("/api/v1/animal-drivers/requests/{$requestId}/accept")
            ->assertStatus(409);
    }

    public function test_supplier_can_create_and_list_transport_requests_only_for_its_own_profile(): void
    {
        $supplier = User::factory()->create(['role' => 'animalSupplier']);
        SupplierProfile::create([
            'user_id' => $supplier->id,
            'reference' => fake()->uuid(),
            'business_registration_number' => 'BRN-'.fake()->unique()->numerify('#####'),
            'business_name' => 'Green Barn Supplies',
            'county' => 'Nairobi',
            'product_categories' => 'Feed',
            'status' => 'approved',
            'subscription_expires_at' => now()->addDays(30),
        ]);
        $createdRequest = $this->actingAs($supplier, 'sanctum')
            ->postJson('/api/v1/animal-suppliers/transport-requests', [
                ...$this->requestData(),
                'service_type' => 'supplies',
            ])
            ->assertCreated()
            ->assertJsonPath('data.service_type', 'supplies');
        $requestId = $createdRequest->json('data.id');
        $this->getJson('/api/v1/animal-suppliers/transport-requests')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $requestId);
        $this->postJson("/api/v1/transport-requests/{$requestId}/status", [
            'status' => 'cancelled',
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');
    }

    private function requestData(): array
    {
        return [
            'service_type' => 'herd',
            'vehicle_type' => 'Livestock lorry',
            'pickup_latitude' => -1.2864,
            'pickup_longitude' => 36.8172,
            'pickup_address' => 'Nairobi Farm',
            'destination_latitude' => -1.2921,
            'destination_longitude' => 36.8219,
            'destination_address' => 'Nairobi Market',
            'load_description' => '10 pigs',
            'radius_km' => 25,
        ];
    }

    private function createDriver(
        string $vehicleType,
        bool $available,
        float $latitude,
        float $longitude,
    ): DriverProfile {
        $user = User::factory()->create(['role' => 'animalDriver']);

        return DriverProfile::create([
            'user_id' => $user->id,
            'reference' => fake()->uuid(),
            'driver_license_number' => 'DL-'.fake()->unique()->numerify('#####'),
            'county' => 'Nairobi',
            'service_types' => 'herd,supplies',
            'vehicle_type' => $vehicleType,
            'vehicle_registration_number' => 'KBB'.fake()->unique()->numerify('###').'A',
            'capacity_description' => 'Livestock transport',
            'status' => 'approved',
            'subscription_expires_at' => now()->addDays(30),
            'latitude' => $latitude,
            'longitude' => $longitude,
            'available' => $available,
            'location_updated_at' => now(),
        ]);
    }
}
