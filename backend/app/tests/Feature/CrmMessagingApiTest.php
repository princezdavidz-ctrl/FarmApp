<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CrmMessagingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_member_can_message_crm_and_crm_can_read_sender_details(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $member = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Messaging Farm']);
        $farm->users()->attach([$owner->id, $member->id]);

        $this->actingAs($member, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/notifications/messages", [
                'message' => 'Please help me with my subscription.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.type', 'crm_message_sent');

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/crm/notifications?farm_id={$farm->id}")
            ->assertOk()
            ->assertJsonPath('data.0.sender_id', $member->id)
            ->assertJsonPath('data.0.sender_name', $member->name)
            ->assertJsonPath('data.0.message', 'Please help me with my subscription.');

        $this->assertDatabaseHas('crm_notifications', [
            'farm_id' => $farm->id,
            'sender_id' => $member->id,
            'message' => 'Please help me with my subscription.',
        ]);
        $this->assertDatabaseHas('farm_notifications', [
            'farm_id' => $farm->id,
            'recipient_id' => $member->id,
            'type' => 'crm_message_sent',
        ]);
    }

    public function test_message_cannot_be_sent_by_a_non_member(): void
    {
        $user = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Private Messaging Farm']);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/notifications/messages", ['message' => 'Hello'])
            ->assertForbidden();

        $this->assertSame(0, DB::table('crm_notifications')->count());
    }

    public function test_crm_reply_is_delivered_back_to_the_app_sender(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $member = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Round Trip Messaging Farm']);
        $farm->users()->attach([$owner->id, $member->id]);

        $this->actingAs($member, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/notifications/messages", [
                'message' => 'Can you confirm my delivery date?',
            ])
            ->assertCreated();

        $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/crm/notifications', [
                'farm_id' => $farm->id,
                'recipient_id' => $member->id,
                'message' => 'Your delivery is confirmed for Friday.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.message', 'Your delivery is confirmed for Friday.');

        $this->actingAs($member, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/notifications")
            ->assertOk()
            ->assertJsonFragment([
                'type' => 'crm_message',
                'body' => 'Your delivery is confirmed for Friday.',
            ]);

        $this->assertDatabaseHas('support_messages', [
            'conversation_id' => DB::table('support_conversations')->where('farm_id', $farm->id)->value('id'),
            'sender_id' => $owner->id,
            'sender_role' => 'crm',
            'body' => 'Your delivery is confirmed for Friday.',
        ]);
        $this->assertDatabaseHas('communication_broadcasts', [
            'farm_id' => $farm->id,
            'sender_id' => $owner->id,
            'recipient_id' => $member->id,
            'audience' => 'individual',
        ]);
    }

    public function test_crm_broadcast_reaches_every_app_member_in_the_farm_notifications(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $manager = User::factory()->create(['role' => 'farmManager']);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $outsider = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Broadcast Farm']);
        $farm->users()->attach([$owner->id, $manager->id, $worker->id, $support->id]);

        $this->actingAs($support, 'sanctum')
            ->postJson('/api/v1/crm/notifications', [
                'farm_id' => $farm->id,
                'kind' => 'broadcast',
                'title' => 'Farm update',
                'message' => 'A new farm-wide announcement.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.recipient_count', 3);

        foreach ([$owner, $manager, $worker] as $recipient) {
            $this->actingAs($recipient, 'sanctum')
                ->getJson("/api/v1/farms/{$farm->id}/notifications")
                ->assertOk()
                ->assertJsonFragment([
                    'type' => 'crm_broadcast',
                    'title' => 'Farm update',
                    'body' => 'A new farm-wide announcement.',
                ]);
        }

        $this->assertDatabaseMissing('farm_notifications', [
            'farm_id' => $farm->id,
            'recipient_id' => $outsider->id,
            'type' => 'crm_broadcast',
        ]);
    }

    public function test_global_admin_can_broadcast_to_registered_app_users_across_all_farms(): void
    {
        $admin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);
        $admin->forceFill(['is_global_crm_admin' => true])->save();
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $manager = User::factory()->create(['role' => 'farmManager']);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $crmStaff = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $closedWorker = User::factory()->create(['role' => 'farmWorker', 'crm_closed_at' => now()]);
        $unaffiliatedWorker = User::factory()->create(['role' => 'farmWorker']);
        $farmOne = Farm::create(['name' => 'Global Broadcast Farm One']);
        $farmTwo = Farm::create(['name' => 'Global Broadcast Farm Two']);
        $farmOne->users()->attach([$owner->id, $worker->id, $crmStaff->id]);
        $farmTwo->users()->attach([$manager->id, $worker->id, $closedWorker->id]);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/notifications', [
                'farm_id' => $farmOne->id,
                'kind' => 'broadcast',
                'audience_scope' => 'all_registered',
                'title' => 'Service announcement',
                'message' => 'A message for all registered app users.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.audience', 'all_registered')
            ->assertJsonPath('data.recipient_count', 3);

        foreach ([$owner, $manager, $worker] as $recipient) {
            $this->assertDatabaseHas('farm_notifications', [
                'recipient_id' => $recipient->id,
                'type' => 'crm_broadcast',
                'title' => 'Service announcement',
                'related_type' => 'global_crm_broadcast',
            ]);
        }

        $this->assertSame(3, DB::table('farm_notifications')
            ->where('related_type', 'global_crm_broadcast')
            ->where('title', 'Service announcement')
            ->distinct('recipient_id')
            ->count('recipient_id'));
        $this->assertDatabaseMissing('farm_notifications', [
            'recipient_id' => $crmStaff->id,
            'title' => 'Service announcement',
        ]);
        $this->assertDatabaseMissing('farm_notifications', [
            'recipient_id' => $closedWorker->id,
            'title' => 'Service announcement',
        ]);
        $this->assertDatabaseMissing('farm_notifications', [
            'recipient_id' => $unaffiliatedWorker->id,
            'title' => 'Service announcement',
        ]);
        $this->assertDatabaseHas('communication_broadcasts', [
            'farm_id' => $farmOne->id,
            'audience' => 'all_registered',
            'title' => 'Service announcement',
        ]);

        $this->actingAs($manager, 'sanctum')
            ->getJson("/api/v1/farms/{$farmTwo->id}/notifications")
            ->assertOk()
            ->assertJsonFragment([
                'title' => 'Service announcement',
                'body' => 'A message for all registered app users.',
            ]);
    }

    public function test_farm_crm_staff_cannot_broadcast_to_all_registered_users(): void
    {
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $member = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Scoped Broadcast Farm']);
        $farm->users()->attach([$support->id, $member->id]);

        $this->actingAs($support, 'sanctum')
            ->postJson('/api/v1/crm/notifications', [
                'farm_id' => $farm->id,
                'kind' => 'broadcast',
                'audience_scope' => 'all_registered',
                'message' => 'This must remain farm-scoped.',
            ])
            ->assertForbidden();

        $this->assertSame(0, DB::table('communication_broadcasts')->count());
    }

    public function test_support_thread_tracks_agent_identity_read_state_and_assignment(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $member = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Threaded Support Farm']);
        $farm->users()->attach([$owner->id, $support->id, $member->id]);

        $this->actingAs($member, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/support-conversation/messages", [
                'message' => 'I need help with my account.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'open')
            ->assertJsonPath('data.messages.0.sender_name', $member->name);

        $conversationId = DB::table('support_conversations')
            ->where('farm_id', $farm->id)
            ->where('app_user_id', $member->id)
            ->value('id');
        $this->assertDatabaseHas('support_conversations', [
            'id' => $conversationId,
            'assigned_user_id' => null,
        ]);

        $this->actingAs($support, 'sanctum')
            ->getJson("/api/v1/crm/support-conversations?farm_id={$farm->id}")
            ->assertOk()
            ->assertJsonPath('data.0.customer.name', $member->name)
            ->assertJsonPath('data.0.unread_count', 1);

        $this->actingAs($support, 'sanctum')
            ->patchJson("/api/v1/crm/support-conversations/{$conversationId}/read")
            ->assertOk();

        $this->actingAs($support, 'sanctum')
            ->postJson('/api/v1/crm/support-presence', [
                'farm_id' => $farm->id,
                'online' => true,
            ])
            ->assertOk()
            ->assertJsonPath('data.online', true);

        $this->actingAs($support, 'sanctum')
            ->getJson("/api/v1/crm/support-conversations?farm_id={$farm->id}")
            ->assertOk();
        $this->assertDatabaseHas('support_conversations', [
            'id' => $conversationId,
            'assigned_user_id' => $support->id,
        ]);

        $this->actingAs($support, 'sanctum')
            ->patchJson("/api/v1/crm/support-conversations/{$conversationId}", [
                'assigned_user_id' => $support->id,
            ])
            ->assertOk()
            ->assertJsonPath('data.assigned_agent.name', $support->name);

        $this->actingAs($support, 'sanctum')
            ->postJson("/api/v1/crm/support-conversations/{$conversationId}/messages", [
                'message' => 'I am Alex from customer support. I will help you.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.sender_name', $support->name);
        $this->assertDatabaseHas('farm_notifications', [
            'farm_id' => $farm->id,
            'recipient_id' => $member->id,
            'type' => 'crm_message',
            'title' => 'Customer Care',
            'body' => 'I am Alex from customer support. I will help you.',
            'related_type' => 'support_conversation',
            'related_id' => $conversationId,
            'action_route' => '/support',
        ]);

        $this->actingAs($member, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/support-conversation")
            ->assertOk()
            ->assertJsonPath('data.messages.1.sender_name', $support->name)
            ->assertJsonPath('data.assigned_agent.name', $support->name);

        $this->actingAs($member, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/support-conversation/read")
            ->assertOk();

        $this->actingAs($support, 'sanctum')
            ->getJson("/api/v1/crm/support-conversations/{$conversationId}")
            ->assertOk()
            ->assertJsonPath('data.unread_count', 0);
    }

    public function test_support_messages_are_assigned_to_an_online_agent_without_open_tasks(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $busyAgent = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $availableAgent = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'admin']);
        $member = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Task-aware Support Farm']);
        $farm->users()->attach([$owner->id, $busyAgent->id, $availableAgent->id, $member->id]);
        $customer = Customer::create([
            'farm_id' => $farm->id,
            'created_by' => $owner->id,
            'assigned_user_id' => $busyAgent->id,
            'name' => 'Busy Agent Customer',
            'email' => 'busy@example.com',
            'phone' => '254700123456',
            'company' => 'Busy Customer Ltd',
            'address' => 'Nairobi',
            'type' => 'buyer',
            'status' => 'new',
            'notes' => '',
        ]);
        DB::table('crm_tasks')->insert([
            'farm_id' => $farm->id,
            'customer_id' => $customer->id,
            'assigned_to' => $busyAgent->id,
            'created_by' => $owner->id,
            'title' => 'Follow up on customer',
            'status' => 'open',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        foreach ([$busyAgent, $availableAgent] as $agent) {
            $this->actingAs($agent, 'sanctum')
                ->postJson('/api/v1/crm/support-presence', [
                    'farm_id' => $farm->id,
                    'online' => true,
                ])
                ->assertOk();
        }

        $this->actingAs($availableAgent, 'sanctum')
            ->getJson("/api/v1/crm/support-presence?farm_id={$farm->id}")
            ->assertOk()
            ->assertJsonPath('data.online_agents.0.id', (string) $availableAgent->id)
            ->assertJsonPath('data.online_agents.0.open_crm_tasks', 0)
            ->assertJsonPath('data.online_agents.1.open_crm_tasks', 1);

        $this->actingAs($member, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/support-conversation/messages", [
                'message' => 'Please contact me about my order.',
            ])
            ->assertCreated();

        $this->assertDatabaseHas('support_conversations', [
            'farm_id' => $farm->id,
            'app_user_id' => $member->id,
            'assigned_user_id' => $availableAgent->id,
        ]);
    }

    public function test_customer_specific_support_threads_are_linked_to_the_correct_customer(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $member = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Customer Thread Farm']);
        $farm->users()->attach([$owner->id, $support->id, $member->id]);
        $customer = Customer::create([
            'farm_id' => $farm->id,
            'created_by' => $owner->id,
            'assigned_user_id' => $support->id,
            'name' => 'Amina Farmer',
            'email' => 'amina@example.com',
            'phone' => '254700123456',
            'company' => 'Amina Poultry',
            'address' => 'Nairobi',
            'type' => 'buyer',
            'status' => 'new',
            'notes' => 'Priority customer',
        ]);

        $this->actingAs($member, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/support-conversation/messages", [
                'customer_id' => $customer->id,
                'message' => 'I need a quote for feed.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.customer.id', (string) $customer->id)
            ->assertJsonPath('data.customer.name', 'Amina Farmer');

        $conversationId = DB::table('support_conversations')
            ->where('farm_id', $farm->id)
            ->where('customer_id', $customer->id)
            ->value('id');

        $this->actingAs($support, 'sanctum')
            ->getJson("/api/v1/crm/support-conversations?farm_id={$farm->id}")
            ->assertOk()
            ->assertJsonPath('data.0.customer.id', (string) $customer->id)
            ->assertJsonPath('data.0.customer.name', 'Amina Farmer');

        $this->actingAs($support, 'sanctum')
            ->getJson("/api/v1/crm/support-conversations/{$conversationId}")
            ->assertOk()
            ->assertJsonPath('data.customer.id', (string) $customer->id);
    }

    public function test_farm_broadcast_is_fanned_out_only_to_other_app_members(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $member = User::factory()->create(['role' => 'farmWorker']);
        $crmStaff = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $outsider = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Broadcast Farm']);
        $farm->users()->attach([$owner->id, $member->id, $crmStaff->id]);
        $otherFarm = Farm::create(['name' => 'Other Farm']);
        $otherFarm->users()->attach($outsider->id);

        $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/crm/notifications', [
                'farm_id' => $farm->id,
                'message' => 'Farm meeting tomorrow at 9.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.audience', 'farm')
            ->assertJsonPath('data.recipient_count', 1);

        $this->assertDatabaseHas('farm_notifications', [
            'farm_id' => $farm->id,
            'recipient_id' => $member->id,
            'body' => 'Farm meeting tomorrow at 9.',
        ]);
        $this->assertDatabaseMissing('farm_notifications', [
            'farm_id' => $farm->id,
            'recipient_id' => $outsider->id,
            'body' => 'Farm meeting tomorrow at 9.',
        ]);
        $this->assertDatabaseMissing('farm_notifications', [
            'farm_id' => $farm->id,
            'recipient_id' => $crmStaff->id,
            'body' => 'Farm meeting tomorrow at 9.',
        ]);

        $this->actingAs($member, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/notifications")
            ->assertOk()
            ->assertJsonFragment(['body' => 'Farm meeting tomorrow at 9.']);
    }

    public function test_support_conversation_and_broadcast_respect_farm_authorization(): void
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $member = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Private Conversation Farm']);
        $farm->users()->attach($owner->id);

        $this->actingAs($member, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/support-conversation/messages", ['message' => 'Unauthorized'])
            ->assertForbidden();

        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $farm->users()->attach($support->id);
        $this->actingAs($support, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/support-conversation/messages", ['message' => 'CRM account cannot impersonate an app user.'])
            ->assertForbidden();

        $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/crm/notifications', [
                'farm_id' => $farm->id,
                'recipient_id' => $member->id,
                'message' => 'Should not deliver.',
            ])
            ->assertUnprocessable();
    }
}
