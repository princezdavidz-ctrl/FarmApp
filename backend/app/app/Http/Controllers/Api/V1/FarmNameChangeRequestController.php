<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CrmAuditLog;
use App\Models\Farm;
use App\Models\FarmNameChangeRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class FarmNameChangeRequestController extends Controller
{
    public function store(Request $request, Farm $farm): JsonResponse
    {
        abort_unless($request->user()->role === 'farmOwner', 403, 'Only the farm owner can request a farm name change.');
        $this->authorizeFarmMembership($request, $farm);
        $validated = $request->validate([
            'requested_name' => ['required', 'string', 'max:255'],
        ]);
        $requestedName = trim($validated['requested_name']);
        abort_if($requestedName === '', 422, 'Enter a farm name.');

        $change = DB::transaction(function () use ($request, $farm, $requestedName): FarmNameChangeRequest {
            $lockedFarm = Farm::query()->lockForUpdate()->findOrFail($farm->id);
            abort_if(mb_strtolower($lockedFarm->name) === mb_strtolower($requestedName), 422, 'The requested name is already in use by this farm.');
            abort_if(
                FarmNameChangeRequest::query()->where('farm_id', $lockedFarm->id)->where('status', 'pending')->exists(),
                409,
                'A farm name change is already awaiting CRM approval.',
            );

            return FarmNameChangeRequest::create([
                'farm_id' => $lockedFarm->id,
                'requested_by' => $request->user()->id,
                'current_name' => $lockedFarm->name,
                'requested_name' => $requestedName,
                'status' => 'pending',
            ]);
        });

        return response()->json(['data' => $this->serialize($change->load(['farm:id,name', 'requester:id,name,email']))], 201);
    }

    public function mine(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeFarmMembership($request, $farm);
        $items = FarmNameChangeRequest::query()
            ->where('farm_id', $farm->id)
            ->where('requested_by', $request->user()->id)
            ->with(['farm:id,name', 'requester:id,name,email', 'reviewer:id,name,email'])
            ->latest()
            ->limit(20)
            ->get()
            ->map(fn (FarmNameChangeRequest $change): array => $this->serialize($change));

        return response()->json(['data' => $items]);
    }

    public function index(Request $request): JsonResponse
    {
        $this->authorizeCrmAdmin($request);
        $filters = $request->validate([
            'status' => ['sometimes', Rule::in(['pending', 'approved', 'rejected', 'all'])],
            'farm_id' => ['sometimes', 'integer'],
        ]);
        $query = FarmNameChangeRequest::query()
            ->with(['farm:id,name', 'requester:id,name,email', 'reviewer:id,name,email']);

        if (! (bool) $request->user()->is_global_crm_admin) {
            $query->whereIn('farm_id', $request->user()->farms()->select('farms.id'));
        }
        if (! empty($filters['farm_id'])) {
            $query->where('farm_id', $filters['farm_id']);
        }
        if (($filters['status'] ?? 'pending') !== 'all') {
            $query->where('status', $filters['status'] ?? 'pending');
        }

        return response()->json([
            'data' => $query->latest()->limit(100)->get()
                ->map(fn (FarmNameChangeRequest $change): array => $this->serialize($change)),
        ]);
    }

    public function review(Request $request, FarmNameChangeRequest $farmNameChangeRequest): JsonResponse
    {
        $this->authorizeCrmAdmin($request);
        $data = $request->validate([
            'status' => ['required', Rule::in(['approved', 'rejected'])],
            'review_notes' => ['nullable', 'string', 'max:2000'],
        ]);
        $change = DB::transaction(function () use ($request, $farmNameChangeRequest, $data): FarmNameChangeRequest {
            $change = FarmNameChangeRequest::query()
                ->with('farm')
                ->lockForUpdate()
                ->findOrFail($farmNameChangeRequest->id);
            abort_if($change->status !== 'pending', 409, 'This request has already been reviewed.');
            abort_if($change->requested_by === $request->user()->id, 403, 'The requester cannot review their own farm name change.');
            if (! (bool) $request->user()->is_global_crm_admin) {
                abort_unless(
                    $request->user()->farms()->whereKey($change->farm_id)->exists(),
                    403,
                    'You cannot review requests for this farm.',
                );
            }

            $previousName = $change->farm->name;
            if ($data['status'] === 'approved') {
                $change->farm->update(['name' => $change->requested_name]);
            }
            $change->update([
                'status' => $data['status'],
                'reviewed_by' => $request->user()->id,
                'review_notes' => $data['review_notes'] ?? null,
                'reviewed_at' => now(),
            ]);
            CrmAuditLog::create([
                'farm_id' => $change->farm_id,
                'user_id' => $request->user()->id,
                'action' => ucfirst($data['status']).' farm name change: '.$change->requested_name,
                'module' => 'Farm settings',
                'metadata' => [
                    'request_id' => $change->id,
                    'previous_name' => $previousName,
                    'requested_name' => $change->requested_name,
                    'review_notes' => $data['review_notes'] ?? null,
                ],
            ]);

            return $change->fresh(['farm:id,name', 'requester:id,name,email', 'reviewer:id,name,email']);
        });

        return response()->json(['data' => $this->serialize($change)]);
    }

    private function authorizeFarmMembership(Request $request, Farm $farm): void
    {
        abort_unless($request->user()->farms()->whereKey($farm->id)->exists(), 403, 'You do not belong to this farm.');
    }

    private function authorizeCrmAdmin(Request $request): void
    {
        abort_unless(
            (bool) $request->user()->is_global_crm_admin ||
                ($request->user()->crm_role ?? null) === 'admin' ||
                $request->user()->role === 'farmOwner',
            403,
            'Only CRM administrators can review farm name changes.',
        );
    }

    private function serialize(FarmNameChangeRequest $change): array
    {
        return [
            'id' => (string) $change->id,
            'farm_id' => (string) $change->farm_id,
            'farm_name' => $change->farm?->name ?? $change->current_name,
            'current_name' => $change->current_name,
            'requested_name' => $change->requested_name,
            'status' => $change->status,
            'review_notes' => $change->review_notes,
            'requested_by' => $change->requester?->name ?? 'Former farm owner',
            'requester_email' => $change->requester?->email,
            'reviewed_by' => $change->reviewer?->name,
            'reviewed_at' => $change->reviewed_at?->toIso8601String(),
            'created_at' => $change->created_at?->toIso8601String(),
        ];
    }
}
