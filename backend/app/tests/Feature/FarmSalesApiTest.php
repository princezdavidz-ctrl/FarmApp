<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FarmSalesApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_manager_can_create_a_buyer_sale_and_update_sale_status(): void
    {
        [$manager, $farm] = $this->farmWithManager();

        $buyerId = $this->actingAs($manager, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/buyers", [
                'name' => 'Nakuru Pork Shop',
                'phone' => '+254700000001',
                'email' => 'orders@example.com',
                'company' => 'Nakuru Pork Shop',
                'status' => 'qualified',
            ])
            ->assertCreated()
            ->assertJsonPath('data.type', 'buyer')
            ->json('data.id');

        $saleId = $this->actingAs($manager, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/sales", [
                'customer_id' => $buyerId,
                'reference' => 'SALE-1001',
                'items' => [['name' => 'Grower pig', 'quantity' => 2, 'unit_price' => 15000]],
                'total_amount' => 1,
                'currency' => 'KES',
                'ordered_at' => '2026-10-06',
                'expected_at' => '2026-10-08',
                'notes' => 'Farm gate pickup.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.customer_name', 'Nakuru Pork Shop')
            ->assertJsonPath('data.total_amount', '30000.00')
            ->assertJsonPath('data.items.0.quantity', 2)
            ->json('data.id');

        $this->assertDatabaseHas('customer_orders', [
            'id' => $saleId,
            'farm_id' => $farm->id,
            'customer_id' => $buyerId,
            'total_amount' => 30000,
        ]);

        $this->actingAs($manager, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/sales/{$saleId}", ['status' => 'completed'])
            ->assertOk()
            ->assertJsonPath('data.status', 'completed')
            ->assertJsonPath('data.completed_at', '2026-10-06');

        $this->actingAs($manager, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/sales")
            ->assertOk()
            ->assertJsonFragment(['reference' => 'SALE-1001']);
    }

    public function test_sale_records_reject_buyers_from_other_farms(): void
    {
        [$manager, $farm] = $this->farmWithManager();
        $otherFarm = Farm::create(['name' => 'Other farm']);
        $otherFarm->users()->attach($manager->id);
        $otherBuyer = $otherFarm->customers()->create([
            'created_by' => $manager->id,
            'name' => 'Other farm buyer',
            'type' => 'buyer',
        ]);

        $this->actingAs($manager, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/sales", [
                'customer_id' => $otherBuyer->id,
                'reference' => 'BAD-SALE',
                'total_amount' => 100,
                'currency' => 'KES',
                'ordered_at' => '2026-10-06',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('customer_id');

        $worker = User::factory()->create(['role' => 'farmWorker']);
        $farm->users()->attach($worker->id);
        $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/sales")
            ->assertForbidden();
    }

    /** @return array{User, Farm} */
    private function farmWithManager(): array
    {
        $manager = User::factory()->create(['role' => 'farmManager']);
        $farm = Farm::create(['name' => 'Sales farm']);
        $farm->users()->attach($manager->id);

        return [$manager, $farm];
    }
}
