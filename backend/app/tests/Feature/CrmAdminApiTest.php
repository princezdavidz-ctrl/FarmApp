<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CrmAdminApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_central_admin_can_manage_farm_owner_prospects_and_notification_templates(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);
        $admin->forceFill(['is_global_crm_admin' => true])->save();

        $prospectId = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/admin/prospects', [
                'owner_name' => 'Amina Otieno',
                'email' => 'amina@example.com',
                'phone' => '+254700123456',
                'farm_name' => 'Green Acres',
                'status' => 'new',
                'notes' => 'Interested in onboarding.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.owner_name', 'Amina Otieno')
            ->assertJsonPath('data.farm_name', 'Green Acres')
            ->json('data.id');

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/v1/crm/admin/prospects/{$prospectId}", ['status' => 'contacted'])
            ->assertOk()
            ->assertJsonPath('data.status', 'contacted');

        $templateId = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/admin/notification-templates', [
                'title' => 'Welcome',
                'message' => 'Welcome to Farm App.',
                'active' => true,
            ])
            ->assertCreated()
            ->assertJsonPath('data.title', 'Welcome')
            ->json('data.id');

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/crm/admin/notification-templates')
            ->assertOk()
            ->assertJsonPath('data.0.id', $templateId);

        $this->actingAs($admin, 'sanctum')
            ->deleteJson("/api/v1/crm/admin/prospects/{$prospectId}")
            ->assertNoContent();

        $this->assertDatabaseMissing('farm_owner_prospects', ['id' => $prospectId]);
    }

    public function test_farm_admin_without_explicit_global_flag_cannot_access_global_crm_features(): void
    {
        $farmAdmin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);

        $this->actingAs($farmAdmin, 'sanctum')
            ->getJson('/api/v1/crm/admin/prospects')
            ->assertForbidden();

        $this->actingAs($farmAdmin, 'sanctum')
            ->postJson('/api/v1/crm/admin/notification-templates', [
                'title' => 'Welcome',
                'message' => 'Hello.',
            ])
            ->assertForbidden();
    }

    public function test_global_admin_can_broadcast_to_another_farm_and_read_history(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);
        $admin->forceFill(['is_global_crm_admin' => true])->save();
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $member = User::factory()->create(['role' => 'farmWorker']);
        $crmStaff = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $farm = Farm::create(['name' => 'Remote Farm']);
        $farm->users()->attach([$owner->id, $member->id, $crmStaff->id]);

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/crm/admin/farms')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Remote Farm')
            ->assertJsonFragment(['id' => (string) $member->id, 'role' => 'farmWorker']);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/notifications', [
                'farm_id' => $farm->id,
                'title' => 'Service update',
                'message' => 'Support hours changed.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.recipient_count', 2);

        $this->assertDatabaseHas('farm_notifications', [
            'farm_id' => $farm->id,
            'recipient_id' => $member->id,
            'title' => 'Service update',
        ]);
        $this->assertDatabaseMissing('farm_notifications', [
            'farm_id' => $farm->id,
            'recipient_id' => $crmStaff->id,
            'title' => 'Service update',
        ]);

        $this->actingAs($admin, 'sanctum')
            ->getJson("/api/v1/crm/broadcasts?farm_id={$farm->id}")
            ->assertOk()
            ->assertJsonPath('data.0.title', 'Service update')
            ->assertJsonPath('data.0.recipient_count', 2);
    }
}
