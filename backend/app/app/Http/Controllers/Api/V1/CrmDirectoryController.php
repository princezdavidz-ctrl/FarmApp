<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Buyer;
use App\Models\Customer;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CrmDirectoryController extends Controller
{
    public function buyers(Request $request): JsonResponse
    {
        $this->authorizeCrmAccess($request);
        $buyers = Buyer::query()
            ->with('user:id,name,email,phone,crm_closed_at,created_at')
            ->withCount('inquiries')
            ->whereHas('user', function ($query) use ($request): void {
                $query->when($request->filled('search'), function ($query) use ($request): void {
                    $term = $request->string('search')->toString();
                    $query->where(function ($query) use ($term): void {
                        $query->where('name', 'like', "%{$term}%")
                            ->orWhere('email', 'like', "%{$term}%")
                            ->orWhere('phone', 'like', "%{$term}%");
                    });
                });
            })
            ->latest('id')
            ->paginate(min(max($request->integer('per_page', 25), 10), 100));

        return response()->json([
            'data' => $buyers->getCollection()->map(fn (Buyer $buyer): array => [
                'id' => (string) $buyer->id,
                'user_id' => (string) $buyer->user_id,
                'name' => $buyer->user?->name,
                'email' => $buyer->user?->email,
                'phone' => $buyer->user?->phone,
                'status' => $buyer->user?->crm_closed_at ? 'suspended' : 'active',
                'registered_at' => $buyer->user?->created_at?->toISOString(),
                'inquiries_count' => (int) $buyer->inquiries_count,
            ])->values(),
            'meta' => [
                'current_page' => $buyers->currentPage(),
                'last_page' => $buyers->lastPage(),
                'per_page' => $buyers->perPage(),
                'total' => $buyers->total(),
            ],
        ]);
    }

    public function overview(Request $request): JsonResponse
    {
        $this->authorizeCrmAccess($request);
        $farmIds = $request->user()->farms()->pluck('farms.id');
        $farms = $request->user()->farms()
            ->with([
                'users' => fn ($query) => $query->select('users.id', 'users.name', 'users.email', 'users.phone', 'users.role', 'users.crm_closed_at'),
                'payments' => fn ($query) => $query->latest('created_at'),
                'animals:id,farm_id,type,sex,status,birth_date',
            ])
            ->orderBy('name')
            ->get();

        $customers = Customer::query()
            ->whereIn('farm_id', $farmIds)
            ->with('farm:id,name')
            ->withCount(['tasks as open_tasks_count' => fn ($query) => $query->where('status', 'open')])
            ->latest()
            ->get()
            ->map(fn (Customer $customer): array => [
                'id' => (string) $customer->id,
                'farm_id' => (string) $customer->farm_id,
                'farm_name' => $customer->farm?->name,
                'name' => $customer->name,
                'email' => $customer->email,
                'phone' => $customer->phone,
                'company' => $customer->company,
                'type' => $customer->type,
                'status' => $customer->status,
                'open_tasks_count' => (int) $customer->open_tasks_count,
            ]);
        $members = User::query()
            ->whereIn('role', ['farmOwner', 'farmManager', 'farmWorker'])
            ->with('farms:id,name')
            ->orderBy('name')
            ->get()
            ->flatMap(function ($member): array {
                $farms = $member->farms;
                if ($farms->isEmpty()) {
                    return [[
                        'id' => (string) $member->id,
                        'farm_id' => null,
                        'farm_name' => 'Not assigned',
                        'name' => $member->name,
                        'email' => $member->email,
                        'phone' => $member->phone,
                        'role' => $member->role,
                        'status' => $member->crm_closed_at ? 'suspended' : 'active',
                    ]];
                }
                return $farms->map(fn ($farm): array => [
                    'id' => (string) $member->id,
                    'farm_id' => (string) $farm->id,
                    'farm_name' => $farm->name,
                    'name' => $member->name,
                    'email' => $member->email,
                    'phone' => $member->phone,
                    'role' => $member->role,
                    'status' => $member->crm_closed_at ? 'suspended' : 'active',
                ])->all();
            })->values();

        $farmOwners = $farms->flatMap(function ($farm): array {
            $owner = $farm->users->firstWhere('role', 'farmOwner');
            if ($owner === null) return [];

            $animals = $farm->animals;
            $piglets = $this->pigletCount($farm, $animals);
            $motherPigs = (int) ($farm->mother_pig_count ?? 0);
            if ($motherPigs === 0) {
                $motherPigs = $animals->filter(fn ($animal) => in_array(strtolower((string) $animal->type), ['sow', 'mother_pig', 'mother pig'], true))->count();
            }
            $numberOfPigs = $animals->count() ?: $motherPigs + $piglets;
            $latestPayment = $farm->payments->first();
            $paymentStatus = $latestPayment?->status ?? 'pending';

            return [[
                'id' => (string) $owner->id,
                'farm_id' => (string) $farm->id,
                'farm_name' => $farm->name,
                'name' => $owner->name,
                'email' => $owner->email,
                'phone' => $owner->phone,
                'role' => $owner->role,
                'status' => $paymentStatus === 'paid' ? 'active' : 'pending',
                'payment_status' => $paymentStatus,
                'number_of_pigs' => $numberOfPigs,
                'mother_pigs' => $motherPigs,
                'piglets' => $piglets,
                'piglet_age_groups' => $this->pigletAgeGroups($farm, $animals),
            ]];
        })->values();

        $relationships = $farms->map(function ($farm): array {
            $users = $farm->users;
            return [
                'farm_id' => (string) $farm->id,
                'farm_name' => $farm->name,
                'owner' => $this->memberSummary($users->firstWhere('role', 'farmOwner'), $farm->id, $farm->name),
                'managers' => $users->where('role', 'farmManager')->values()->map(fn ($member) => $this->memberSummary($member, $farm->id, $farm->name))->values(),
                'workers' => $users->where('role', 'farmWorker')->values()->map(fn ($member) => $this->memberSummary($member, $farm->id, $farm->name))->values(),
                'status' => $users->contains(fn ($member) => $member->role === 'farmOwner' && ! $member->crm_closed_at) ? 'active' : 'attention',
            ];
        })->values();

        return response()->json(['data' => [
            'customers' => $customers,
            'farm_owners' => $farmOwners,
            'farm_managers' => $members->where('role', 'farmManager')->values(),
            'farm_workers' => $members->where('role', 'farmWorker')->values(),
            'relationships' => $relationships,
            'buyers' => Buyer::query()->whereHas('user')->count(),
        ]]);
    }

    private function memberSummary($member, int $farmId, string $farmName): ?array
    {
        if ($member === null) return null;
        return [
            'id' => (string) $member->id,
            'farm_id' => (string) $farmId,
            'farm_name' => $farmName,
            'name' => $member->name,
            'email' => $member->email,
            'phone' => $member->phone,
            'role' => $member->role,
        ];
    }

    private function pigletCount($farm, $animals): int
    {
        $animalPiglets = $animals->filter(fn ($animal) => in_array(strtolower((string) $animal->type), ['piglet', 'piglet_group'], true))->count();
        if ($animalPiglets > 0) return $animalPiglets;

        return collect($farm->piglet_groups ?? [])->sum(fn ($group) => (int) ($group['count'] ?? 0));
    }

    private function pigletAgeGroups($farm, $animals): array
    {
        $storedGroups = collect($farm->piglet_groups ?? [])
            ->map(fn ($group): array => [
                'count' => (int) ($group['count'] ?? 0),
                'age_months' => (int) ($group['age_months'] ?? 0),
            ])->values()->all();
        if ($storedGroups !== []) return $storedGroups;

        return $animals
            ->filter(fn ($animal) => in_array(strtolower((string) $animal->type), ['piglet', 'piglet_group'], true) && $animal->birth_date)
            ->groupBy(fn ($animal) => $animal->birth_date->diffInMonths(now()))
            ->map(fn ($group, $age): array => ['count' => $group->count(), 'age_months' => (int) $age])
            ->values()->all();
    }

    private function authorizeCrmAccess(Request $request): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (! in_array($role, ['admin', 'finance', 'customer_support'], true)) {
            abort(403, 'Only CRM staff can access directories.');
        }
    }
}
