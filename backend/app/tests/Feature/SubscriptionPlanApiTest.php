<?php

namespace Tests\Feature;

use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SubscriptionPlanApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_crm_admin_can_create_a_subscription_plan(): void
    {
        $user = User::factory()->create(['crm_role' => 'admin']);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/subscription-plans', [
                'code' => 'pro_plus',
                'name' => 'Pro Plus',
                'description' => 'For established farms.',
                'amount' => 45,
                'currency' => 'usd',
                'pig_limit' => 500,
                'active' => true,
            ])
            ->assertCreated()
            ->assertJsonPath('data.code', 'pro_plus')
            ->assertJsonPath('data.currency', 'USD')
            ->assertJsonPath('data.amount', '45.00');

        $this->assertDatabaseHas('subscription_plans', [
            'code' => 'pro_plus',
            'currency' => 'USD',
        ]);
    }

    public function test_plan_creation_rejects_duplicate_codes_and_invalid_values(): void
    {
        $user = User::factory()->create(['crm_role' => 'finance']);
        SubscriptionPlan::create([
            'code' => 'starter',
            'name' => 'Starter',
            'amount' => 10,
            'currency' => 'USD',
            'active' => true,
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/subscription-plans', [
                'code' => 'starter',
                'name' => 'Duplicate',
                'amount' => -1,
                'currency' => 'US',
                'pig_limit' => 0,
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['code', 'amount', 'currency', 'pig_limit']);
    }

    public function test_only_plan_managers_can_mutate_the_catalog(): void
    {
        $worker = User::factory()->create(['role' => 'worker']);
        $plan = SubscriptionPlan::create([
            'code' => 'starter',
            'name' => 'Starter',
            'amount' => 10,
            'currency' => 'USD',
            'active' => true,
        ]);

        $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/subscription-plans', [
                'code' => 'worker_plan',
                'name' => 'Worker Plan',
                'amount' => 10,
                'currency' => 'USD',
            ])
            ->assertForbidden();

        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/subscription-plans/{$plan->id}", ['name' => 'Changed'])
            ->assertForbidden();
    }

    public function test_normal_plan_viewers_only_see_active_plans_and_managers_can_retire_them(): void
    {
        $manager = User::factory()->create(['crm_role' => 'admin']);
        $viewer = User::factory()->create(['role' => 'farmOwner']);
        SubscriptionPlan::create([
            'code' => 'active_plan',
            'name' => 'Active Plan',
            'amount' => 10,
            'currency' => 'USD',
            'active' => true,
        ]);
        SubscriptionPlan::create([
            'code' => 'retired_plan',
            'name' => 'Retired Plan',
            'amount' => 20,
            'currency' => 'USD',
            'active' => false,
        ]);

        $this->actingAs($viewer, 'sanctum')
            ->getJson('/api/v1/subscription-plans')
            ->assertOk()
            ->assertJsonPath('data.0.code', 'active_plan')
            ->assertJsonMissing(['code' => 'retired_plan']);

        $plan = SubscriptionPlan::where('code', 'active_plan')->firstOrFail();
        $this->actingAs($manager, 'sanctum')
            ->deleteJson("/api/v1/subscription-plans/{$plan->id}")
            ->assertNoContent();

        $this->assertDatabaseHas('subscription_plans', [
            'id' => $plan->id,
            'active' => false,
        ]);
    }
}
