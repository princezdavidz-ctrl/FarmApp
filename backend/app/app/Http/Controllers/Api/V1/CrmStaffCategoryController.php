<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CrmAuditLog;
use App\Models\StaffCategory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class CrmStaffCategoryController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $this->authorizeStaffAccess($request);
        $farmId = $request->integer('farm_id');
        $this->authorizeFarm($request, $farmId);
        $this->ensureDefaultCategories($farmId);
        return response()->json(['data' => StaffCategory::where('farm_id', $farmId)->where('active', true)->orderBy('name')->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request);
        $data = $request->validate([
            'farm_id' => ['required', 'integer', 'exists:farms,id'],
            'name' => ['required', 'string', 'max:80'],
            'icon' => ['nullable', 'string', 'max:8'],
            'color' => ['nullable', 'string', 'max:20'],
        ]);
        $this->authorizeFarm($request, (int) $data['farm_id']);
        $slug = Str::slug($data['name']);
        if (StaffCategory::where('farm_id', $data['farm_id'])->where('slug', $slug)->exists()) {
            throw ValidationException::withMessages(['name' => ['This staff category already exists in the farm.']]);
        }
        $category = StaffCategory::create([
            'farm_id' => $data['farm_id'],
            'name' => $data['name'],
            'slug' => $slug,
            'icon' => $data['icon'] ?? '•',
            'color' => $data['color'] ?? '#286846',
        ]);
        CrmAuditLog::create([
            'farm_id' => $data['farm_id'],
            'user_id' => $request->user()->id,
            'action' => 'Created staff category: '.$category->name,
            'module' => 'Staff categories',
            'metadata' => ['category_id' => $category->id],
        ]);
        return response()->json(['data' => $category], 201);
    }

    public function destroy(Request $request, StaffCategory $staffCategory): JsonResponse
    {
        $this->authorizeAdmin($request);
        $this->authorizeFarm($request, $staffCategory->farm_id);
        CrmAuditLog::create([
            'farm_id' => $staffCategory->farm_id,
            'user_id' => $request->user()->id,
            'action' => 'Deleted staff category: '.$staffCategory->name,
            'module' => 'Staff categories',
            'metadata' => ['category_id' => $staffCategory->id],
        ]);
        $staffCategory->delete();
        return response()->json(null, 204);
    }

    private function authorizeAdmin(Request $request): void
    {
        if (($request->user()->crm_role ?? null) !== 'admin' && $request->user()->role !== 'farmOwner') abort(403, 'Only CRM admins can manage staff categories.');
    }

    private function authorizeStaffAccess(Request $request): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (! in_array($role, ['admin', 'finance', 'customer_support'], true)) abort(403, 'Only CRM staff can access staff categories.');
    }

    private function authorizeFarm(Request $request, int $farmId): void
    {
        if (! $request->user()->farms()->whereKey($farmId)->exists()) abort(403, 'You do not have access to this farm.');
    }

    private function ensureDefaultCategories(int $farmId): void
    {
        foreach ([['Finance', '₿', '#286846'], ['Customer service', '✦', '#5b9c98']] as [$name, $icon, $color]) {
            StaffCategory::firstOrCreate(['farm_id' => $farmId, 'slug' => Str::slug($name)], ['name' => $name, 'icon' => $icon, 'color' => $color, 'active' => true]);
        }
    }
}
