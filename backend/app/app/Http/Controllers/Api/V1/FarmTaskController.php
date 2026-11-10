<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\StoreFarmTaskRequest;
use App\Http\Requests\Farm\UpdateFarmTaskRequest;
use App\Http\Resources\Farm\FarmTaskResource;
use App\Models\Farm;
use App\Models\FarmTask;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class FarmTaskController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $membership = $this->authorizeView($request, $farm);
        $query = $farm->tasks()->with('assignee:id,name,email');

        // Workers only see tasks assigned to them and tasks that have not yet been assigned.
        if ($request->user()->crm_role === null && $request->user()->role === 'farmWorker') {
            $query->where(fn ($tasks) => $tasks->where('assigned_to', $request->user()->id)
                ->orWhereNull('assigned_to'));
        }

        $query
            ->when($request->filled('status'), fn ($tasks) => $tasks->where('status', $request->string('status')))
            ->when($request->filled('priority'), fn ($tasks) => $tasks->where('priority', $request->string('priority')))
            ->when($request->filled('category'), fn ($tasks) => $tasks->where('category', $request->string('category')))
            ->when($request->boolean('overdue'), fn ($tasks) => $tasks->where('status', 'open')->whereNotNull('due_at')->where('due_at', '<', now()))
            ->when($request->filled('search'), function ($tasks) use ($request) {
                $search = $request->string('search')->toString();
                $tasks->where(fn ($query) => $query->where('title', 'like', "%{$search}%")
                    ->orWhere('notes', 'like', "%{$search}%"));
            })
            ->orderByRaw("CASE WHEN status = 'open' THEN 0 ELSE 1 END")
            ->orderByRaw('due_at IS NULL')
            ->orderBy('due_at')
            ->latest();

        return response()->json(['data' => FarmTaskResource::collection($query->get())]);
    }

    public function store(StoreFarmTaskRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeManage($request, $farm);
        $data = $request->validated();
        $this->validateAssignee($request, $farm, $data['assigned_to'] ?? null);
        $task = $farm->tasks()->create($data + ['created_by' => $request->user()->id]);

        return response()->json(['data' => new FarmTaskResource($task->load('assignee:id,name,email'))], 201);
    }

    public function update(UpdateFarmTaskRequest $request, Farm $farm, FarmTask $task): JsonResponse
    {
        $this->assertTaskBelongsToFarm($farm, $task);
        $user = $request->user();
        $data = $request->validated();

        if ($this->canManage($request, $farm)) {
            $this->validateAssignee($request, $farm, $data['assigned_to'] ?? $task->assigned_to);
        } else {
            $this->authorizeView($request, $farm);
            abort_if($user->crm_role !== null, 403, 'This CRM role cannot change farm tasks.');
            abort_unless((int) $task->assigned_to === (int) $user->id, 403, 'You can only update tasks assigned to you.');
            abort_unless(array_keys($data) === ['status'], 403, 'Farm workers can only change task status.');
        }

        $wasCompleted = $task->status === 'completed';
        $task->fill($data);
        if (($data['status'] ?? null) === 'completed') {
            $task->completed_at = now();
        } elseif ($wasCompleted && array_key_exists('status', $data)) {
            $task->completed_at = null;
        }
        $task->save();

        return response()->json(['data' => new FarmTaskResource($task->fresh()->load('assignee:id,name,email'))]);
    }

    public function destroy(Request $request, Farm $farm, FarmTask $task): JsonResponse
    {
        $this->assertTaskBelongsToFarm($farm, $task);
        $this->authorizeManage($request, $farm);
        $task->delete();

        return response()->json(null, 204);
    }

    private function authorizeView(Request $request, Farm $farm): object
    {
        $user = $request->user();
        $membership = $user->farms()->where('farms.id', $farm->id)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');
        abort_if($user->crm_closed_at !== null, 403, 'This CRM account is inactive.');
        if ($user->role === 'farmOwner') return $membership;

        if (in_array($user->crm_role, ['admin', 'finance', 'customer_support'], true)) {
            return $membership;
        }

        $permissions = $membership->pivot->permissions === null
            ? $this->defaultPermissions($user->role)
            : json_decode($membership->pivot->permissions, true);
        abort_unless(in_array('viewTasks', $permissions ?? [], true)
            || in_array('manageTasks', $permissions ?? [], true), 403, 'You do not have permission to view farm tasks.');

        return $membership;
    }

    private function authorizeManage(Request $request, Farm $farm): void
    {
        abort_unless($this->canManage($request, $farm), 403, 'You do not have permission to manage farm tasks.');
    }

    private function canManage(Request $request, Farm $farm): bool
    {
        $user = $request->user();
        $membership = $user->farms()->where('farms.id', $farm->id)->first();
        if ($membership === null) return false;
        if ($user->crm_closed_at !== null) return false;
        if ($user->role === 'farmOwner') return true;
        if (in_array($user->crm_role, ['admin', 'finance'], true)) return true;
        $permissions = $membership->pivot->permissions === null
            ? $this->defaultPermissions($user->role)
            : json_decode($membership->pivot->permissions, true);

        return in_array('manageTasks', $permissions ?? [], true);
    }

    private function validateAssignee(Request $request, Farm $farm, ?int $userId): void
    {
        if ($userId === null) return;
        if (! $farm->users()->whereKey($userId)->exists()) {
            throw ValidationException::withMessages(['assigned_to' => ['The assignee must be a member of this farm.']]);
        }
    }

    private function assertTaskBelongsToFarm(Farm $farm, FarmTask $task): void
    {
        abort_if((int) $task->farm_id !== (int) $farm->id, 404);
    }

    private function defaultPermissions(string $role): array
    {
        return match ($role) {
            'farmManager' => ['viewTasks', 'manageTasks'],
            'farmWorker' => ['viewTasks'],
            default => [],
        };
    }
}
