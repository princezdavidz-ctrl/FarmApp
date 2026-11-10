<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\Payment;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FarmBillingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_owner_can_view_recent_payment_history_without_phone_numbers(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Billing Farm']);
        $owner->farms()->attach($farm);
        Payment::create([
            'farm_id' => $farm->id,
            'user_id' => $owner->id,
            'plan_code' => 'starter',
            'mother_pig_count' => 12,
            'amount' => 10,
            'currency' => 'KES',
            'phone' => '254700000001',
            'status' => 'paid',
            'mpesa_receipt' => 'QWE123',
            'paid_at' => now(),
        ]);
        Sanctum::actingAs($owner);

        $this->getJson("/api/v1/farms/{$farm->id}/payments")
            ->assertOk()
            ->assertJsonPath('data.0.plan_code', 'starter')
            ->assertJsonPath('data.0.status', 'paid')
            ->assertJsonPath('data.0.receipt', 'QWE123')
            ->assertJsonMissingPath('data.0.phone');
    }

    public function test_non_owner_cannot_view_farm_billing_history(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Private Billing Farm']);
        $owner->farms()->attach($farm);
        $worker->farms()->attach($farm);
        Sanctum::actingAs($worker);

        $this->getJson("/api/v1/farms/{$farm->id}/payments")->assertForbidden();
    }

    public function test_farm_owner_cannot_select_a_paid_plan_without_successful_payment(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Unpaid Plan Farm']);
        $owner->farms()->attach($farm);
        $plan = SubscriptionPlan::create([
            'code' => 'premium',
            'name' => 'Premium',
            'amount' => 100,
            'currency' => 'KES',
            'active' => true,
        ]);
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/farms/{$farm->id}/subscription", ['plan' => $plan->code])
            ->assertUnprocessable();

        $this->assertDatabaseHas('farms', ['id' => $farm->id, 'subscription_plan' => null]);
    }

    public function test_farm_owner_can_select_a_free_plan_without_payment(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Free Plan Farm']);
        $owner->farms()->attach($farm);
        $plan = SubscriptionPlan::create([
            'code' => 'free',
            'name' => 'Free',
            'amount' => 0,
            'currency' => 'KES',
            'active' => true,
        ]);
        Sanctum::actingAs($owner);

        $this->patchJson("/api/v1/farms/{$farm->id}/subscription", ['plan' => $plan->code])
            ->assertOk();

        $this->assertDatabaseHas('farms', ['id' => $farm->id, 'subscription_plan' => $plan->code]);
    }
}
