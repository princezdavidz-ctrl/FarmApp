<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Crm\StoreCrmTaskRequest;
use App\Http\Requests\Crm\UpdateCrmTaskRequest;
use App\Http\Resources\Crm\CrmTaskResource;
use App\Models\CrmCustomerEvent;
use App\Models\CrmTask;
use App\Models\Customer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class CrmTaskController extends Controller
{
    public function farmIndex(Request $request): JsonResponse
    {
        $farmId = $request->integer('farm_id');
        $this->authorizeFarm($request, $farmId);

        $tasks = CrmTask::query()
            ->where('farm_id', $farmId)
            ->with(['assignee:id,name,email', 'customer:id,name,email,company'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('assigned_to'), fn ($query) => $query->where('assigned_to', $request->integer('assigned_to')))
            ->when($request->filled('priority'), fn ($query) => $query->where('priority', $request->string('priority')))
            ->when($request->boolean('overdue'), fn ($query) => $query->where('status', 'open')->whereNotNull('due_at')->where('due_at', '<', now()))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = $request->string('search')->toString();
                $query->where(function ($taskQuery) use ($search) {
                    $taskQuery->where('title', 'like', "%{$search}%")
                        ->orWhereHas('customer', fn ($customerQuery) => $customerQuery->where('name', 'like', "%{$search}%"));
                });
            })
            ->orderByRaw("CASE WHEN status = 'open' THEN 0 ELSE 1 END")
            ->orderByRaw('due_at IS NULL')
            ->orderBy('due_at')
            ->latest()
            ->get();

        return response()->json(['data' => CrmTaskResource::collection($tasks)]);
    }

    public function index(Request $request, Customer $customer): JsonResponse
    {
        $this->authorizeCustomer($request, $customer);

        $tasks = $customer->tasks()
            ->with('assignee:id,name,email')
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('assigned_to'), fn ($query) => $query->where('assigned_to', $request->integer('assigned_to')))
            ->orderByRaw("CASE WHEN status = 'open' THEN 0 ELSE 1 END")
            ->orderByRaw('due_at IS NULL')
            ->orderBy('due_at')
            ->latest()
            ->get();

        return response()->json(['data' => CrmTaskResource::collection($tasks)]);
    }

    public function store(StoreCrmTaskRequest $request, Customer $customer): JsonResponse
    {
        $this->authorizeCustomer($request, $customer);
        $data = $request->validated();
        $this->validateAssignee($request, $customer, $data['assigned_to'] ?? null);

        $task = $customer->tasks()->create($data + [
            'farm_id' => $customer->farm_id,
            'created_by' => $request->user()->id,
        ]);

        $this->recordEvent($customer, $request, 'task_created', ['task_id' => $task->id, 'title' => $task->title]);

        return response()->json(['data' => new CrmTaskResource($task->load('assignee:id,name,email'))], 201);
    }

    public function update(UpdateCrmTaskRequest $request, Customer $customer, CrmTask $task): JsonResponse
    {
        $this->authorizeCustomer($request, $customer);
        if ((int) $task->customer_id !== (int) $customer->id) abort(404);

        $data = $request->validated();
        $this->validateAssignee($request, $customer, $data['assigned_to'] ?? $task->assigned_to);
        $wasOpen = $task->status === 'open';
        $task->fill($data);
        if (array_key_exists('status', $data) && $data['status'] === 'completed') {
            $task->completed_at = now();
        } elseif ($wasOpen && ($data['status'] ?? null) !== 'completed') {
            $task->completed_at = null;
        }
        $task->save();

        $this->recordEvent($customer, $request, 'task_updated', ['task_id' => $task->id, 'status' => $task->status]);

        return response()->json(['data' => new CrmTaskResource($task->load('assignee:id,name,email'))]);
    }

    public function destroy(Request $request, Customer $customer, CrmTask $task): JsonResponse
    {
        $this->authorizeCustomer($request, $customer);
        if ((int) $task->customer_id !== (int) $customer->id) abort(404);

        $task->delete();
        $this->recordEvent($customer, $request, 'task_deleted', ['task_id' => $task->id, 'title' => $task->title]);

        return response()->json(null, 204);
    }

    private function authorizeCustomer(Request $request, Customer $customer): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (! in_array($role, ['admin', 'finance', 'customer_support'], true)) {
            abort(403, 'Only CRM staff can manage follow-up tasks.');
        }
        if (! $request->user()->farms()->where('farms.id', $customer->farm_id)->exists()) {
            throw ValidationException::withMessages(['farm_id' => ['You do not have access to this farm.']]);
        }
    }

    private function authorizeFarm(Request $request, int $farmId): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (! in_array($role, ['admin', 'finance', 'customer_support'], true)) {
            abort(403, 'Only CRM staff can manage follow-up tasks.');
        }
        if ($farmId < 1 || ! $request->user()->farms()->whereKey($farmId)->exists()) {
            abort(403, 'You do not have access to this farm.');
        }
    }

    private function validateAssignee(Request $request, Customer $customer, ?int $userId): void
    {
        if ($userId === null) return;
        $assignee = $request->user()->farms()
            ->where('farms.id', $customer->farm_id)
            ->with(['users' => fn ($query) => $query->whereKey($userId)])
            ->first()
            ?->users
            ?->first();
        $role = $assignee?->crm_role ?? ($assignee?->role === 'farmOwner' ? 'admin' : null);
        if ($assignee === null || ! in_array($role, ['admin', 'finance', 'customer_support'], true)) {
            throw ValidationException::withMessages(['assigned_to' => ['The assignee must be CRM staff in this farm.']]);
        }
    }

    private function recordEvent(Customer $customer, Request $request, string $type, array $data): void
    {
        CrmCustomerEvent::create([
            'customer_id' => $customer->id,
            'user_id' => $request->user()->id,
            'type' => $type,
            'data' => $data,
            'occurred_at' => now(),
        ]);
    }
}
