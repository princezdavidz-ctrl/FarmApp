<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\FarmTask;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FarmTaskApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_manager_can_create_and_assign_a_farm_task_to_a_worker(): void
    {
        [$manager, $worker, $farm] = $this->farmWithManagerAndWorker();

        $taskId = $this->actingAs($manager, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/tasks", [
                'title' => 'Check evening feed',
                'assigned_to' => $worker->id,
                'priority' => 'high',
                'category' => 'feeding',
                'due_at' => '2026-10-08T16:30:00+03:00',
                'notes' => 'Check the nursery batch.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.title', 'Check evening feed')
            ->assertJsonPath('data.priority', 'high')
            ->assertJsonPath('data.category', 'feeding')
            ->assertJsonPath('data.assignee.id', (string) $worker->id)
            ->json('data.id');

        $this->assertDatabaseHas('farm_tasks', [
            'id' => $taskId,
            'farm_id' => $farm->id,
            'assigned_to' => $worker->id,
            'created_by' => $manager->id,
        ]);
    }

    public function test_workers_only_see_their_tasks_and_can_only_change_their_status(): void
    {
        [$manager, $worker, $farm] = $this->farmWithManagerAndWorker();
        $assigned = $this->task($farm, $manager, $worker, 'Assigned to worker');
        $other = $this->task($farm, $manager, $manager, 'Assigned to manager');

        $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/tasks")
            ->assertOk()
            ->assertJsonFragment(['title' => 'Assigned to worker'])
            ->assertJsonMissing(['title' => 'Assigned to manager']);

        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/tasks/{$assigned->id}", ['status' => 'completed'])
            ->assertOk()
            ->assertJsonPath('data.status', 'completed');

        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/tasks/{$assigned->id}", ['title' => 'Changed by worker'])
            ->assertForbidden();

        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/tasks/{$other->id}", ['status' => 'completed'])
            ->assertForbidden();

        $this->actingAs($worker, 'sanctum')
            ->deleteJson("/api/v1/farms/{$farm->id}/tasks/{$assigned->id}")
            ->assertForbidden();
    }

    public function test_task_assignees_and_task_routes_cannot_cross_farm_boundaries(): void
    {
        [$manager, $worker, $farm] = $this->farmWithManagerAndWorker();
        $otherFarm = Farm::create(['name' => 'Other farm']);
        $otherFarm->users()->attach($manager->id);
        $outsider = User::factory()->create(['role' => 'farmWorker']);
        $otherTask = $this->task($otherFarm, $manager, null, 'Private task');

        $this->actingAs($manager, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/tasks", [
                'title' => 'Invalid assignment',
                'assigned_to' => $outsider->id,
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('assigned_to');

        $this->actingAs($manager, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/tasks/{$otherTask->id}", ['status' => 'completed'])
            ->assertNotFound();
    }

    public function test_a_user_without_task_permission_cannot_read_or_create_tasks(): void
    {
        $viewer = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Read restricted farm']);
        $farm->users()->attach($viewer->id, ['permissions' => json_encode(['viewDashboard'])]);

        $this->actingAs($viewer, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/tasks")
            ->assertForbidden();

        $this->actingAs($viewer, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/tasks", ['title' => 'Not allowed'])
            ->assertForbidden();
    }

    public function test_crm_finance_can_manage_farm_tasks_while_support_is_read_only(): void
    {
        $finance = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'finance']);
        $support = User::factory()->create(['role' => 'farmWorker', 'crm_role' => 'customer_support']);
        $farm = Farm::create(['name' => 'CRM task farm']);
        $farm->users()->attach([$finance->id, $support->id]);

        $taskId = $this->actingAs($finance, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/tasks", ['title' => 'CRM assigned task'])
            ->assertCreated()
            ->json('data.id');

        $this->actingAs($support, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/tasks")
            ->assertOk()
            ->assertJsonFragment(['title' => 'CRM assigned task']);

        $this->actingAs($support, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/tasks/{$taskId}", ['status' => 'completed'])
            ->assertForbidden();
    }

    /** @return array{User, User, Farm} */
    private function farmWithManagerAndWorker(): array
    {
        $manager = User::factory()->create(['role' => 'farmManager']);
        $worker = User::factory()->create(['role' => 'farmWorker']);
        $farm = Farm::create(['name' => 'Task farm']);
        $farm->users()->attach([$manager->id, $worker->id]);

        return [$manager, $worker, $farm];
    }

    private function task(Farm $farm, User $manager, ?User $assignee, string $title): FarmTask
    {
        return $farm->tasks()->create([
            'created_by' => $manager->id,
            'assigned_to' => $assignee?->id,
            'title' => $title,
            'priority' => 'normal',
            'category' => 'other',
            'status' => 'open',
        ]);
    }
}
