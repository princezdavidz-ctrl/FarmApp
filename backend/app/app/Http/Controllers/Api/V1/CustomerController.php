<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Crm\StoreCustomerRequest;
use App\Http\Requests\Crm\UpdateCustomerRequest;
use App\Http\Resources\Crm\CustomerResource;
use App\Models\CrmCustomerEvent;
use App\Models\Customer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class CustomerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $this->authorizeCrmAccess($request);
        $farmIds = $request->user()->farms()->pluck('farms.id');

        $sortBy = $request->string('sort_by', 'latest')->toString();
        $sortDirection = $request->string('sort_direction', 'desc')->lower()->toString() === 'asc' ? 'asc' : 'desc';
        $sortColumns = [
            'name' => 'name',
            'status' => 'status',
            'created_at' => 'created_at',
            'updated_at' => 'updated_at',
        ];
        $customers = Customer::query()
            ->whereIn('farm_id', $farmIds)
            ->with(['assignee:id,name,email,crm_role', 'farm:id,name'])
            ->withCount(['tasks as open_tasks_count' => fn ($query) => $query->where('status', 'open')])
            ->withMin(['tasks as next_task_due_at' => fn ($query) => $query->where('status', 'open')->whereNotNull('due_at')], 'due_at')
            ->when($request->filled('farm_id'), fn ($query) => $query->where('farm_id', $request->integer('farm_id')))
            ->when($request->filled('assigned_to'), fn ($query) => $query->where('assigned_user_id', $request->integer('assigned_to')))
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('type'), fn ($query) => $query->where('type', $request->string('type')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = $request->string('search')->toString();
                $query->where(function ($query) use ($term) {
                    $query->where('name', 'like', "%{$term}%")
                        ->orWhere('email', 'like', "%{$term}%")
                        ->orWhere('company', 'like', "%{$term}%");
                });
            })
            ->when(isset($sortColumns[$sortBy]), fn ($query) => $query->orderBy($sortColumns[$sortBy], $sortDirection))
            ->when($sortBy === 'latest', fn ($query) => $query->latest())
            ->paginate(min(max($request->integer('per_page', 25), 10), 100));

        return response()->json([
            'data' => CustomerResource::collection($customers->items()),
            'meta' => [
                'current_page' => $customers->currentPage(),
                'last_page' => $customers->lastPage(),
                'per_page' => $customers->perPage(),
                'total' => $customers->total(),
            ],
        ]);
    }

    public function store(StoreCustomerRequest $request): JsonResponse
    {
        $this->authorizeCrmAction($request, 'write');
        $this->authorizeFarm($request, $request->integer('farm_id'));
        $this->validateAssignee($request, $request->integer('farm_id'), $request->input('assigned_user_id'));

        $customer = Customer::create([
            ...$request->validated(),
            'created_by' => $request->user()->id,
        ]);
        $this->recordEvent($customer, $request, 'customer_created', []);

        return response()->json(['data' => new CustomerResource($customer->load('assignee:id,name,email,crm_role'))], 201);
    }

    public function show(Request $request, Customer $customer): JsonResponse
    {
        $this->authorizeCrmAccess($request);
        $this->authorizeFarm($request, $customer->farm_id);

        return response()->json(['data' => new CustomerResource($customer->load(['assignee:id,name,email,crm_role', 'farm:id,name']))]);
    }

    public function update(UpdateCustomerRequest $request, Customer $customer): JsonResponse
    {
        $this->authorizeCrmAccess($request);
        $this->authorizeCrmAction($request, 'write');
        $this->authorizeFarm($request, $customer->farm_id);

        $data = $request->validated();
        $this->validateAssignee($request, $customer->farm_id, $data['assigned_user_id'] ?? $customer->assigned_user_id);
        $previousStatus = $customer->status;
        $previousAssignee = $customer->assigned_user_id;
        $customer->update($data);
        if (array_key_exists('status', $data) && $previousStatus !== $customer->status) {
            $this->recordEvent($customer, $request, 'status_changed', ['from' => $previousStatus, 'to' => $customer->status]);
        }
        if (array_key_exists('assigned_user_id', $data) && (int) $previousAssignee !== (int) $customer->assigned_user_id) {
            $this->recordEvent($customer, $request, 'assignment_changed', ['from' => $previousAssignee, 'to' => $customer->assigned_user_id]);
        }

        return response()->json(['data' => new CustomerResource($customer->load('assignee:id,name,email,crm_role'))]);
    }

    public function destroy(Request $request, Customer $customer): JsonResponse
    {
        $this->authorizeCrmAccess($request);
        $this->authorizeCrmAction($request, 'delete');
        $this->authorizeFarm($request, $customer->farm_id);

        $customer->delete();

        return response()->json(null, 204);
    }

    private function authorizeFarm(Request $request, int $farmId): void
    {
        $belongsToFarm = $request->user()->farms()->where('farms.id', $farmId)->exists();

        if (! $belongsToFarm) {
            throw ValidationException::withMessages(['farm_id' => ['You do not have access to this farm.']]);
        }
    }

    private function authorizeCrmAction(Request $request, string $action): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if ($action === 'delete' && $role !== 'admin') abort(403, 'Only CRM admins can delete customers.');
        if ($action === 'write' && !in_array($role, ['admin', 'finance'], true)) abort(403, 'This CRM role is read-only for customer records.');
    }

    private function authorizeCrmAccess(Request $request): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (! in_array($role, ['admin', 'finance', 'customer_support'], true)) {
            abort(403, 'Only CRM staff can access customer records.');
        }
    }

    private function validateAssignee(Request $request, int $farmId, mixed $userId): void
    {
        if ($userId === null) return;
        $assignee = $request->user()->farms()
            ->where('farms.id', $farmId)
            ->with(['users' => fn ($query) => $query->whereKey($userId)])
            ->first()
            ?->users
            ?->first();
        $role = $assignee?->crm_role ?? ($assignee?->role === 'farmOwner' ? 'admin' : null);
        if ($assignee === null || ! in_array($role, ['admin', 'finance', 'customer_support'], true)) {
            throw ValidationException::withMessages(['assigned_user_id' => ['The assignee must be CRM staff in this farm.']]);
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
