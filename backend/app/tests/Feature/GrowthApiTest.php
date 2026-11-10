<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class GrowthApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_fetch_growth_overview_and_records(): void
    {
        $user = User::factory()->create([
            'role' => 'farmOwner',
            'email' => 'owner@example.com',
        ]);

        $farm = Farm::create(['name' => 'Green Valley Farm']);
        $user->farms()->attach($farm);

        $token = $user->createToken('test-token')->plainTextToken;

        $this->withToken($token)
            ->getJson('/api/v1/farms/' . $farm->id . '/growth-overview')
            ->assertOk();

        $this->withToken($token)
            ->getJson('/api/v1/farms/' . $farm->id . '/growth-records')
            ->assertOk();

        $this->withToken($token)
            ->getJson('/api/v1/farms/' . $farm->id . '/growth-analytics?period=30days')
            ->assertOk();
    }
}
