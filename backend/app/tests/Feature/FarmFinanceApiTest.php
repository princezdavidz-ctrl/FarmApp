<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FarmFinanceApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_record_income_and_expense_and_read_farm_scoped_totals(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Finance farm']);
        $owner->farms()->attach($farm);

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/finance", [
                'type' => 'income',
                'category' => 'Livestock sales',
                'description' => 'Sold two piglets',
                'amount' => 25000,
                'currency' => 'kes',
                'occurred_at' => now()->toDateString(),
            ])
            ->assertCreated()
            ->assertJsonFragment(['currency' => 'KES']);

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/finance", [
                'type' => 'expense',
                'category' => 'Feed',
                'description' => 'Purchased grower feed',
                'amount' => 7500,
                'currency' => 'KES',
                'occurred_at' => now()->toDateString(),
            ])
            ->assertCreated();

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/finance")
            ->assertOk()
            ->assertJsonFragment([
                'currency' => 'KES',
                'income' => 25000,
                'expenses' => 7500,
                'profit' => 17500,
            ])
            ->assertJsonCount(2, 'data');
    }

    public function test_finance_endpoints_enforce_farm_membership_and_finance_permission(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Private farm']);
        $owner->farms()->attach($farm);
        $outsider = User::factory()->create(['role' => 'farmOwner']);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $accountant = User::factory()->create(['role' => 'accountant']);
        $manager = User::factory()->create(['role' => 'farmManager']);
        $farm->users()->attach($worker->id);
        $farm->users()->attach($accountant->id);
        $farm->users()->attach($manager->id, [
            'permissions' => json_encode(['manageFinance']),
        ]);

        $this->actingAs($outsider, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/finance")
            ->assertForbidden();

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/finance", [
                'type' => 'expense',
                'category' => 'Feed',
                'description' => 'Unauthorized transaction',
                'amount' => 100,
                'currency' => 'KES',
                'occurred_at' => now()->toDateString(),
            ])
            ->assertForbidden();

        $this->actingAs($accountant, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/finance")
            ->assertOk();

        $this->actingAs($manager, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/finance", [
                'type' => 'expense',
                'category' => 'Feed',
                'description' => 'Authorized manager transaction',
                'amount' => 100,
                'currency' => 'KES',
                'occurred_at' => now()->toDateString(),
            ])
            ->assertCreated();
    }
}
