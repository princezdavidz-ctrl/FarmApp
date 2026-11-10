<?php

namespace Tests\Feature;

use App\Models\CrmAuditLog;
use App\Models\CrmPolicy;
use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CrmPolicyApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_create_update_and_list_farm_scoped_policies(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);
        $farm = Farm::create(['name' => 'Policy Farm']);
        $farm->users()->attach($admin->id);

        $policyId = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/policies', [
                'farm_id' => $farm->id,
                'title' => 'Access policy',
                'category' => 'All staff',
                'audience' => 'all',
                'status' => 'active',
                'effective_date' => '2026-10-01',
                'summary' => 'Use only assigned CRM pages.',
                'details' => 'Review access when duties change.',
                'notes' => 'Review quarterly.',
                'visible_pages' => ['Home', 'Customers'],
            ])
            ->assertCreated()
            ->assertJsonPath('data.title', 'Access policy')
            ->assertJsonPath('data.visiblePages.1', 'Customers')
            ->json('data.id');

        $this->actingAs($admin, 'sanctum')
            ->putJson("/api/v1/crm/policies/{$policyId}", [
                'title' => 'Updated access policy',
                'category' => 'All staff',
                'audience' => 'all',
                'status' => 'archived',
                'effective_date' => '2026-10-02',
                'summary' => 'Updated guidance.',
                'details' => '',
                'notes' => '',
                'visible_pages' => ['Home'],
            ])
            ->assertOk()
            ->assertJsonPath('data.title', 'Updated access policy')
            ->assertJsonPath('data.status', 'archived')
            ->assertJsonPath('data.updatedBy', $admin->name);

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/crm/policies?farm_id='.$farm->id)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', (string) $policyId);
    }

    public function test_non_admin_cannot_manage_policies_or_read_another_farm(): void
    {
        $finance = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'finance']);
        $farm = Farm::create(['name' => 'Policy Farm']);
        $farm->users()->attach($finance->id);

        $this->actingAs($finance, 'sanctum')
            ->postJson('/api/v1/crm/policies', [
                'farm_id' => $farm->id,
                'title' => 'Denied',
                'audience' => 'all',
                'effective_date' => '2026-10-01',
                'summary' => 'Denied',
                'visible_pages' => ['Home'],
            ])
            ->assertForbidden();

        $otherFarm = Farm::create(['name' => 'Other Farm']);
        $this->actingAs($finance, 'sanctum')
            ->getJson('/api/v1/crm/policies?farm_id='.$otherFarm->id)
            ->assertForbidden();

        $this->assertDatabaseCount('crm_policies', 0);
    }

    public function test_crm_staff_can_append_audit_entries_but_only_admins_can_read_them(): void
    {
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $admin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);
        $farm = Farm::create(['name' => 'Audit Farm']);
        $farm->users()->attach([$support->id, $admin->id]);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/policies', [
                'farm_id' => $farm->id,
                'title' => 'Audit policy',
                'audience' => 'all',
                'effective_date' => '2026-10-01',
                'summary' => 'Policy changes are recorded.',
                'visible_pages' => ['Home'],
            ])
            ->assertCreated();

        $this->actingAs($support, 'sanctum')
            ->getJson('/api/v1/crm/audit-logs?farm_id='.$farm->id)
            ->assertForbidden();

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/crm/audit-logs?farm_id='.$farm->id)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.metadata.policy_id', CrmPolicy::first()->id)
            ->assertJsonPath('data.0.staff', $admin->name)
            ->assertJsonPath('data.0.action', 'Published staff policy: Audit policy');

        $this->assertSame(1, CrmAuditLog::where('farm_id', $farm->id)->count());
        $this->actingAs($support, 'sanctum')
            ->postJson('/api/v1/crm/audit-logs', ['farm_id' => $farm->id, 'action' => 'Forged entry', 'module' => 'Staff'])
            ->assertMethodNotAllowed();
    }

    public function test_staff_account_mutations_create_server_attributed_audit_records(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);
        $farm = Farm::create(['name' => 'Staff Audit Farm']);
        $farm->users()->attach($admin->id);

        $memberId = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/members', [
                'farm_id' => $farm->id,
                'name' => 'New Staff Member',
                'email' => 'new.staff@example.com',
                'password' => 'temporary-password',
                'crm_role' => 'finance',
            ])
            ->assertCreated()
            ->json('data.id');

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/v1/crm/members/{$memberId}", ['crm_role' => 'customer_support'])
            ->assertOk();

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/crm/audit-logs?farm_id='.$farm->id)
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonFragment(['action' => 'Added CRM account: New Staff Member'])
            ->assertJsonFragment(['action' => 'Updated CRM account role: New Staff Member']);

        $this->actingAs($admin, 'sanctum')
            ->deleteJson("/api/v1/crm/members/{$memberId}")
            ->assertNoContent();

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/crm/audit-logs?farm_id='.$farm->id)
            ->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonFragment(['action' => 'Deleted CRM account: New Staff Member']);
    }
}
