<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CrmNotificationTemplate;
use App\Models\Farm;
use App\Models\FarmOwnerProspect;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CrmAdminController extends Controller
{
    public function farms(Request $request): JsonResponse
    {
        $this->authorizeGlobal($request);
        $farms = Farm::query()->with(['users' => fn ($query) => $query
            ->where(function ($members) {
                $members->where('users.role', 'farmOwner')
                    ->orWhere(fn ($staff) => $staff->whereIn('users.role', ['farmManager', 'farmWorker'])->whereNull('users.crm_role'));
            })
            ->whereNull('users.crm_closed_at')
            ->orderBy('users.name')])
            ->orderBy('name')
            ->get(['id', 'name', 'location']);

        return response()->json(['data' => $farms->map(fn (Farm $farm): array => [
            'id' => (string) $farm->id,
            'name' => $farm->name,
            'location' => $farm->location,
            'members' => $farm->users->map(fn ($user): array => [
                'id' => (string) $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
            ])->values(),
        ])]);
    }

    public function prospects(Request $request): JsonResponse
    {
        $this->authorizeGlobal($request);
        $data = $request->validate([
            'search' => ['sometimes', 'string', 'max:255'],
            'status' => ['sometimes', Rule::in(['new', 'contacted', 'qualified', 'converted', 'closed'])],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
        $items = FarmOwnerProspect::query()
            ->with('creator:id,name')
            ->when($request->filled('status'), fn ($query) => $query->where('status', $data['status']))
            ->when($request->filled('search'), function ($query) use ($data) {
                $term = trim($data['search']);
                $query->where(fn ($search) => $search->where('owner_name', 'like', "%{$term}%")
                    ->orWhere('farm_name', 'like', "%{$term}%")
                    ->orWhere('email', 'like', "%{$term}%")
                    ->orWhere('phone', 'like', "%{$term}%"));
            })
            ->latest()
            ->paginate($data['per_page'] ?? 25);

        return response()->json([
            'data' => $items->getCollection()->map(fn (FarmOwnerProspect $item): array => $this->prospectData($item)),
            'meta' => ['current_page' => $items->currentPage(), 'last_page' => $items->lastPage(), 'total' => $items->total()],
        ]);
    }

    public function storeProspect(Request $request): JsonResponse
    {
        $this->authorizeGlobal($request);
        $data = $this->validateProspect($request);
        $prospect = FarmOwnerProspect::create($data + ['created_by' => $request->user()->id]);

        return response()->json(['data' => $this->prospectData($prospect->load('creator:id,name'))], 201);
    }

    public function updateProspect(Request $request, FarmOwnerProspect $prospect): JsonResponse
    {
        $this->authorizeGlobal($request);
        $prospect->update($this->validateProspect($request, true));

        return response()->json(['data' => $this->prospectData($prospect->fresh('creator:id,name'))]);
    }

    public function deleteProspect(Request $request, FarmOwnerProspect $prospect): JsonResponse
    {
        $this->authorizeGlobal($request);
        $prospect->delete();

        return response()->json(null, 204);
    }

    public function templates(Request $request): JsonResponse
    {
        $this->authorizeGlobal($request);

        return response()->json(['data' => CrmNotificationTemplate::query()->latest()->get()]);
    }

    public function storeTemplate(Request $request): JsonResponse
    {
        $this->authorizeGlobal($request);
        $template = CrmNotificationTemplate::create($this->validateTemplate($request) + [
            'created_by' => $request->user()->id,
        ]);

        return response()->json(['data' => $template], 201);
    }

    public function updateTemplate(Request $request, CrmNotificationTemplate $template): JsonResponse
    {
        $this->authorizeGlobal($request);
        $template->update($this->validateTemplate($request, true));

        return response()->json(['data' => $template->fresh()]);
    }

    public function deleteTemplate(Request $request, CrmNotificationTemplate $template): JsonResponse
    {
        $this->authorizeGlobal($request);
        $template->delete();

        return response()->json(null, 204);
    }

    private function authorizeGlobal(Request $request): void
    {
        abort_unless((bool) $request->user()->is_global_crm_admin, 403, 'Only the central CRM administrator can access this feature.');
    }

    private function validateProspect(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'owner_name' => [$required, 'string', 'max:255'],
            'email' => ['sometimes', 'nullable', 'email', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
            'farm_name' => [$required, 'string', 'max:255'],
            'status' => ['sometimes', Rule::in(['new', 'contacted', 'qualified', 'converted', 'closed'])],
            'notes' => ['sometimes', 'nullable', 'string', 'max:10000'],
        ]);
    }

    private function validateTemplate(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'title' => [$required, 'string', 'max:160'],
            'message' => [$required, 'string', 'max:1000'],
            'active' => ['sometimes', 'boolean'],
        ]);
    }

    private function prospectData(FarmOwnerProspect $prospect): array
    {
        return [
            'id' => (string) $prospect->id,
            'owner_name' => $prospect->owner_name,
            'email' => $prospect->email,
            'phone' => $prospect->phone,
            'farm_name' => $prospect->farm_name,
            'status' => $prospect->status,
            'notes' => $prospect->notes,
            'created_by' => (string) $prospect->created_by,
            'creator_name' => $prospect->creator?->name,
            'created_at' => $prospect->created_at?->toIso8601String(),
            'updated_at' => $prospect->updated_at?->toIso8601String(),
        ];
    }
}
