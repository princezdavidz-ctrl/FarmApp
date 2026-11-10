<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CrmAuditLog;
use App\Models\CrmPolicy;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CrmPolicyController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $this->authorizeStaffAccess($request);
        $farmId = $request->integer('farm_id');
        $this->authorizeFarm($request, $farmId);

        $policies = CrmPolicy::query()
            ->where('farm_id', $farmId)
            ->with(['creator:id,name', 'updater:id,name'])
            ->latest()
            ->get()
            ->map(fn (CrmPolicy $policy): array => $this->serialize($policy));

        return response()->json(['data' => $policies]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);
        $data = $request->validate($this->rules(true));
        $this->authorizeFarm($request, (int) $data['farm_id']);
        $data['created_by'] = $request->user()->id;
        $data['updated_by'] = $request->user()->id;

        $policy = CrmPolicy::create($data);
        $this->recordAudit($policy, $request, 'Published staff policy: '.$policy->title);

        return response()->json(['data' => $this->serialize($policy)], 201);
    }

    public function update(Request $request, CrmPolicy $policy): JsonResponse
    {
        $this->authorizeAdmin($request);
        $this->authorizeFarm($request, $policy->farm_id);
        $data = $request->validate($this->rules(false));
        unset($data['farm_id']);
        $data['updated_by'] = $request->user()->id;
        $wasArchived = $policy->status !== 'archived' && ($data['status'] ?? $policy->status) === 'archived';
        $policy->update($data);
        $this->recordAudit($policy, $request, ($wasArchived ? 'Archived' : 'Updated').' staff policy: '.$policy->title);

        return response()->json(['data' => $this->serialize($policy->fresh())]);
    }

    private function rules(bool $creating): array
    {
        return [
            'farm_id' => [$creating ? 'required' : 'sometimes', 'integer', 'exists:farms,id'],
            'title' => ['required', 'string', 'max:160'],
            'category' => ['nullable', 'string', 'max:80'],
            'audience' => ['required', 'in:all,finance,customer_support'],
            'status' => ['sometimes', 'in:active,archived'],
            'effective_date' => ['required', 'date'],
            'summary' => ['required', 'string', 'max:5000'],
            'details' => ['nullable', 'string', 'max:10000'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'visible_pages' => ['required', 'array', 'max:40'],
            'visible_pages.*' => ['string', 'max:80'],
        ];
    }

    private function serialize(CrmPolicy $policy): array
    {
        return [
            'id' => (string) $policy->id,
            'farm_id' => (string) $policy->farm_id,
            'title' => $policy->title,
            'category' => $policy->category,
            'audience' => $policy->audience,
            'status' => $policy->status,
            'effectiveDate' => $policy->effective_date?->format('Y-m-d'),
            'summary' => $policy->summary,
            'details' => $policy->details ?? '',
            'notes' => $policy->notes ?? '',
            'visiblePages' => $policy->visible_pages ?? [],
            'createdBy' => $policy->creator?->name ?? 'CRM user',
            'updatedBy' => $policy->updater?->name ?? 'CRM user',
            'created_at' => $policy->created_at?->toIso8601String(),
            'updated_at' => $policy->updated_at?->toIso8601String(),
        ];
    }

    private function recordAudit(CrmPolicy $policy, Request $request, string $action): void
    {
        CrmAuditLog::create([
            'farm_id' => $policy->farm_id,
            'user_id' => $request->user()->id,
            'action' => $action,
            'module' => 'Staff policies',
            'metadata' => ['policy_id' => $policy->id],
        ]);
    }

    private function authorizeAdmin(Request $request): void
    {
        if (($request->user()->crm_role ?? null) !== 'admin' && $request->user()->role !== 'farmOwner') {
            abort(403, 'Only CRM admins can manage staff policies.');
        }
    }

    private function authorizeStaffAccess(Request $request): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (! in_array($role, ['admin', 'finance', 'customer_support'], true)) {
            abort(403, 'Only CRM staff can access staff policies.');
        }
    }

    private function authorizeFarm(Request $request, int $farmId): void
    {
        if (! $request->user()->farms()->whereKey($farmId)->exists()) {
            abort(403, 'You do not have access to this farm.');
        }
    }
}
