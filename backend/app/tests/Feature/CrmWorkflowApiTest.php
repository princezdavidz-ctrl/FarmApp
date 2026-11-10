<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\CrmTask;
use App\Models\Farm;
use App\Models\CustomerOrder;
use App\Models\Animal;
use App\Models\Buyer;
use App\Models\FeedStock;
use App\Models\HealthRecord;
use App\Models\InventoryItem;
use App\Models\InventoryMovement;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CrmWorkflowApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_crm_staff_can_filter_farm_tasks_with_customer_context(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner']);
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $farm = Farm::create(['name' => 'Task Queue Farm']);
        $farm->users()->attach([$admin->id, $support->id]);
        $customer = Customer::create(['farm_id' => $farm->id, 'created_by' => $admin->id, 'name' => 'Queue Customer']);
        CrmTask::create([
            'farm_id' => $farm->id,
            'customer_id' => $customer->id,
            'created_by' => $admin->id,
            'assigned_to' => $support->id,
            'title' => 'High priority call',
            'priority' => 'high',
            'due_at' => now()->addDay(),
        ]);

        $this->actingAs($support, 'sanctum')
            ->getJson('/api/v1/crm/tasks?farm_id='.$farm->id.'&priority=high&search=Queue')
            ->assertOk()
            ->assertJsonPath('data.0.title', 'High priority call')
            ->assertJsonPath('data.0.customer.name', 'Queue Customer')
            ->assertJsonPath('data.0.assignee.name', $support->name);

        $otherFarm = Farm::create(['name' => 'Other Task Farm']);
        $this->actingAs($support, 'sanctum')
            ->getJson('/api/v1/crm/tasks?farm_id='.$otherFarm->id)
            ->assertForbidden();
    }

    public function test_crm_staff_can_assign_customer_create_tasks_and_read_timeline(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner']);
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $farm = Farm::create(['name' => 'Workflow Farm']);
        $farm->users()->attach([$admin->id, $support->id]);

        $customer = Customer::create([
            'farm_id' => $farm->id,
            'created_by' => $admin->id,
            'name' => 'Workflow Customer',
            'status' => 'new',
        ]);

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/v1/crm/customers/{$customer->id}", [
                'assigned_user_id' => $support->id,
                'status' => 'contacted',
            ])
            ->assertOk()
            ->assertJsonPath('data.assigned_user_id', (string) $support->id)
            ->assertJsonPath('data.status', 'contacted');

        $task = $this->actingAs($support, 'sanctum')
            ->postJson("/api/v1/crm/customers/{$customer->id}/tasks", [
                'assigned_to' => $support->id,
                'title' => 'Call customer',
                'priority' => 'high',
                'due_at' => '2026-09-12 10:00:00',
            ])
            ->assertCreated()
            ->assertJsonPath('data.title', 'Call customer')
            ->json('data.id');

        $this->actingAs($support, 'sanctum')
            ->patchJson("/api/v1/crm/customers/{$customer->id}/tasks/{$task}", ['status' => 'completed'])
            ->assertOk()
            ->assertJsonPath('data.status', 'completed');

        $this->actingAs($admin, 'sanctum')
            ->getJson("/api/v1/crm/customers/{$customer->id}/timeline")
            ->assertOk()
            ->assertJsonFragment(['type' => 'status_changed'])
            ->assertJsonFragment(['type' => 'assignment_changed'])
            ->assertJsonFragment(['type' => 'task_created'])
            ->assertJsonFragment(['type' => 'task_updated']);
    }

    public function test_assignees_must_be_crm_staff_in_the_customer_farm(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner']);
        $outsider = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'finance']);
        $farm = Farm::create(['name' => 'Private Farm']);
        $farm->users()->attach($admin->id);
        $customer = Customer::create(['farm_id' => $farm->id, 'created_by' => $admin->id, 'name' => 'Private Customer']);

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/crm/customers/{$customer->id}/tasks", [
                'assigned_to' => $outsider->id,
                'title' => 'Invalid assignment',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('assigned_to');
    }

    public function test_crm_dashboard_returns_farm_scoped_operational_metrics(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner']);
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $otherFarm = Farm::create(['name' => 'Other Farm']);
        $farm = Farm::create(['name' => 'Dashboard Farm']);
        $farm->users()->attach([$admin->id, $support->id]);
        $otherFarm->users()->attach(User::factory()->create(['role' => 'farmOwner'])->id);
        Payment::create([
            'farm_id' => $farm->id,
            'user_id' => $admin->id,
            'plan_code' => 'starter',
            'mother_pig_count' => 1,
            'amount' => 100,
            'currency' => 'KES',
            'phone' => '254712345678',
            'status' => 'paid',
            'paid_at' => now(),
        ]);

        $customer = Customer::create([
            'farm_id' => $farm->id,
            'created_by' => $admin->id,
            'name' => 'Dashboard Customer',
            'status' => 'qualified',
        ]);
        Customer::create([
            'farm_id' => $otherFarm->id,
            'created_by' => $admin->id,
            'name' => 'Other Customer',
            'status' => 'won',
        ]);
        CrmTask::create([
            'farm_id' => $farm->id,
            'customer_id' => $customer->id,
            'created_by' => $admin->id,
            'title' => 'Due today',
            'due_at' => now()->addHours(2),
            'assigned_to' => $support->id,
        ]);

        $this->actingAs($support, 'sanctum')
            ->getJson('/api/v1/crm/dashboard/overview?farm_id='.$farm->id)
            ->assertOk()
            ->assertJsonPath('data.customers.total', 2)
            ->assertJsonPath('data.customers.active', 2)
            ->assertJsonPath('data.customers.farm_owners', 1)
            ->assertJsonPath('data.customers.qualified', 1)
            ->assertJsonPath('data.customers.by_status.qualified', 1)
            ->assertJsonPath('data.tasks.due_today', 1)
            ->assertJsonPath('data.tasks.items.0.customer_name', 'Dashboard Customer')
            ->assertJsonFragment(['open_tasks' => 1]);
    }

    public function test_crm_dashboard_rejects_another_farm(): void
    {
        $user = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $farm = Farm::create(['name' => 'Accessible Farm']);
        $otherFarm = Farm::create(['name' => 'Restricted Farm']);
        $farm->users()->attach($user->id);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/crm/dashboard/overview?farm_id='.$otherFarm->id)
            ->assertForbidden();
    }

    public function test_directory_groups_accessible_farm_members_by_role(): void
    {
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $manager = User::factory()->create(['role' => 'farmManager']);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $unassignedWorker = User::factory()->create(['role' => 'farmWorker']);
        $buyer = User::factory()->create(['role' => 'buyer']);
        Buyer::create(['user_id' => $buyer->id]);
        $farm = Farm::create(['name' => 'Directory Farm']);
        $farm->users()->attach([$support->id, $owner->id, $manager->id, $worker->id]);

        $this->actingAs($support, 'sanctum')
            ->getJson('/api/v1/crm/directories/overview')
            ->assertOk()
            ->assertJsonPath('data.buyers', 1)
            ->assertJsonFragment(['name' => $owner->name, 'farm_name' => 'Directory Farm', 'role' => 'farmOwner'])
            ->assertJsonFragment(['name' => $manager->name, 'farm_name' => 'Directory Farm', 'role' => 'farmManager'])
            ->assertJsonFragment(['name' => $worker->name, 'farm_name' => 'Directory Farm', 'role' => 'farmWorker'])
            ->assertJsonFragment(['name' => $unassignedWorker->name, 'farm_name' => 'Not assigned', 'role' => 'farmWorker'])
            ->assertJsonPath('data.relationships.0.farm_name', 'Directory Farm')
            ->assertJsonPath('data.relationships.0.owner.name', $owner->name)
            ->assertJsonCount(1, 'data.relationships.0.managers')
            ->assertJsonCount(2, 'data.relationships.0.workers');
    }

    public function test_crm_operations_lists_feed_medicine_and_emergency_records_for_accessible_farms(): void
    {
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Operations Farm']);
        $farm->users()->attach([$support->id, $owner->id]);
        $otherFarm = Farm::create(['name' => 'Other Operations Farm']);
        $animal = Animal::create([
            'farm_id' => $farm->id,
            'created_by' => $owner->id,
            'tag' => 'PIG-EMERGENCY',
            'type' => 'sow',
            'sex' => 'female',
            'status' => 'active',
        ]);

        FeedStock::create([
            'farm_id' => $farm->id,
            'created_by' => $owner->id,
            'name' => 'Grower feed',
            'quantity' => 12,
            'unit' => 'bags',
        ]);
        FeedStock::create([
            'farm_id' => $otherFarm->id,
            'created_by' => $owner->id,
            'name' => 'Unrelated feed',
            'quantity' => 4,
            'unit' => 'bags',
        ]);

        $medicine = InventoryItem::create([
            'farm_id' => $farm->id,
            'created_by' => $owner->id,
            'name' => 'Antibiotic',
            'category' => 'Medicine',
            'sku' => 'OPS-MED-1',
            'quantity' => 8,
            'unit' => 'bottles',
            'minimum_level' => 1,
            'cost_price' => 25,
        ]);
        InventoryMovement::create([
            'inventory_item_id' => $medicine->id,
            'type' => 'stock_in',
            'quantity' => 8,
            'reference' => 'PO-101',
            'recorded_by' => $owner->id,
        ]);
        $feedItem = InventoryItem::create([
            'farm_id' => $farm->id,
            'created_by' => $owner->id,
            'name' => 'Feed additive',
            'category' => 'Feed',
            'sku' => 'OPS-FEED-1',
            'quantity' => 3,
            'unit' => 'bags',
            'minimum_level' => 1,
            'cost_price' => 10,
        ]);
        InventoryMovement::create([
            'inventory_item_id' => $feedItem->id,
            'type' => 'stock_in',
            'quantity' => 3,
            'recorded_by' => $owner->id,
        ]);

        HealthRecord::create([
            'farm_id' => $farm->id,
            'animal_id' => $animal->id,
            'created_by' => $owner->id,
            'type' => 'treatment',
            'status' => 'critical',
            'diagnosis' => 'Urgent case',
        ]);
        HealthRecord::create([
            'farm_id' => $farm->id,
            'animal_id' => $animal->id,
            'created_by' => $owner->id,
            'type' => 'treatment',
            'status' => 'healthy',
            'diagnosis' => 'Routine check',
        ]);

        $this->actingAs($support, 'sanctum')
            ->getJson('/api/v1/crm/operations/feed-orders')
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.farm_name', 'Operations Farm')
            ->assertJsonPath('data.0.feed', 'Grower feed');

        $this->actingAs($support, 'sanctum')
            ->getJson('/api/v1/crm/operations/medicine-orders')
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.medicine', 'Antibiotic')
            ->assertJsonPath('data.0.reference', 'PO-101');

        $this->actingAs($support, 'sanctum')
            ->getJson('/api/v1/crm/operations/emergencies')
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.pig_tag', 'PIG-EMERGENCY')
            ->assertJsonPath('data.0.diagnosis', 'Urgent case');
    }

    public function test_crm_staff_can_view_registered_buyer_accounts(): void
    {
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $buyer = User::factory()->create([
            'role' => 'buyer',
            'name' => 'Registered Buyer',
            'email' => 'buyer@example.com',
            'phone' => '254712345678',
        ]);
        Buyer::create(['user_id' => $buyer->id]);
        User::factory()->create(['role' => 'farmWorker', 'name' => 'Not a Buyer']);

        $this->actingAs($support, 'sanctum')
            ->getJson('/api/v1/crm/buyers?search=buyer')
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.name', 'Registered Buyer')
            ->assertJsonPath('data.0.email', 'buyer@example.com')
            ->assertJsonPath('data.0.phone', '254712345678')
            ->assertJsonPath('data.0.status', 'active')
            ->assertJsonPath('data.0.inquiries_count', 0);
    }

    public function test_non_crm_users_cannot_view_registered_buyer_accounts(): void
    {
        $buyer = User::factory()->create(['role' => 'buyer']);

        $this->actingAs($buyer, 'sanctum')
            ->getJson('/api/v1/crm/buyers')
            ->assertForbidden();
    }

    public function test_farm_owner_directory_reports_payment_status_and_herd_details(): void
    {
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create([
            'name' => 'Paid Directory Farm',
            'mother_pig_count' => 4,
            'piglet_groups' => [['count' => 6, 'age_months' => 3]],
        ]);
        $farm->users()->attach([$support->id, $owner->id]);
        Payment::create([
            'farm_id' => $farm->id,
            'user_id' => $owner->id,
            'plan_code' => 'starter',
            'mother_pig_count' => 4,
            'amount' => 100,
            'currency' => 'KES',
            'phone' => '254712345678',
            'status' => 'paid',
            'paid_at' => now(),
        ]);

        $this->actingAs($support, 'sanctum')
            ->getJson('/api/v1/crm/directories/overview')
            ->assertOk()
            ->assertJsonPath('data.farm_owners.0.status', 'active')
            ->assertJsonPath('data.farm_owners.0.payment_status', 'paid')
            ->assertJsonPath('data.farm_owners.0.number_of_pigs', 10)
            ->assertJsonPath('data.farm_owners.0.mother_pigs', 4)
            ->assertJsonPath('data.farm_owners.0.piglets', 6)
            ->assertJsonPath('data.farm_owners.0.piglet_age_groups.0.age_months', 3);
    }

    public function test_staff_list_contains_only_crm_accounts(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);
        $crmStaff = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'finance']);
        $farmOwner = User::factory()->create(['role' => 'farmOwner', 'crm_role' => null]);
        $manager = User::factory()->create(['role' => 'farmManager', 'crm_role' => null]);
        $worker = User::factory()->create(['role' => 'farmWorker', 'crm_role' => null]);
        $farm = Farm::create(['name' => 'Staff Farm']);
        $farm->users()->attach([$admin->id, $crmStaff->id, $farmOwner->id, $manager->id, $worker->id]);

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/crm/members?farm_id='.$farm->id)
            ->assertOk()
            ->assertJsonFragment(['name' => $crmStaff->name, 'crm_role' => 'finance'])
            ->assertJsonMissing(['name' => $farmOwner->name])
            ->assertJsonMissing(['name' => $manager->name])
            ->assertJsonMissing(['name' => $worker->name]);
    }

    public function test_admin_can_create_staff_category_and_non_admin_cannot(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $farm = Farm::create(['name' => 'Category Farm']);
        $farm->users()->attach([$admin->id, $support->id]);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/staff-categories', ['farm_id' => $farm->id, 'name' => 'Technology', 'icon' => '*'])
            ->assertCreated()
            ->assertJsonPath('data.name', 'Technology');

        $this->actingAs($support, 'sanctum')
            ->postJson('/api/v1/crm/staff-categories', ['farm_id' => $farm->id, 'name' => 'Operations'])
            ->assertForbidden();
    }

    public function test_customer_orders_are_scoped_and_filterable_by_status(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Orders Farm']);
        $farm->users()->attach($admin->id);
        $customer = Customer::create(['farm_id' => $farm->id, 'created_by' => $admin->id, 'name' => 'Order Customer']);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/orders', [
                'farm_id' => $farm->id,
                'customer_id' => $customer->id,
                'reference' => 'ORD-001',
                'status' => 'pending',
                'total_amount' => 12500,
                'currency' => 'KES',
                'ordered_at' => '2026-09-10',
            ])
            ->assertCreated()
            ->assertJsonPath('data.reference', 'ORD-001')
            ->assertJsonPath('data.customer_name', 'Order Customer');

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/crm/orders?status=pending')
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.status', 'pending');
    }
}
