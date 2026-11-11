<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\StoreCropActivityRequest;
use App\Http\Requests\Farm\UpdateCropActivityRequest;
use App\Models\CropActivity;
use App\Models\Farm;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CropActivityController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeView($request, $farm);

        $activities = $farm->cropActivities()
            ->when($request->filled('crop_cycle_id'), fn ($query) => $query->where('crop_cycle_id', $request->input('crop_cycle_id')))
            ->when($request->filled('activity_type'), fn ($query) => $query->where('activity_type', $request->input('activity_type')))
            ->latest('activity_date')
            ->latest('id')
            ->get();

        return response()->json(['data' => $activities]);
    }

    public function store(StoreCropActivityRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeManage($request, $farm);
        $activity = $farm->cropActivities()->create($request->validated());

        return response()->json(['data' => $activity], 201);
    }

    public function update(UpdateCropActivityRequest $request, Farm $farm, CropActivity $cropActivity): JsonResponse
    {
        $this->assertBelongsToFarm($farm, $cropActivity);
        $this->authorizeManage($request, $farm);
        $cropActivity->update($request->validated());

        return response()->json(['data' => $cropActivity->fresh()]);
    }

    public function destroy(Request $request, Farm $farm, CropActivity $cropActivity): JsonResponse
    {
        $this->assertBelongsToFarm($farm, $cropActivity);
        $this->authorizeManage($request, $farm);
        $cropActivity->delete();

        return response()->json(null, 204);
    }

    private function authorizeView(Request $request, Farm $farm): void
    {
        $membership = $request->user()->farms()->where('farms.id', $farm->id)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');
        abort_if($request->user()->crm_closed_at !== null, 403, 'This CRM account is inactive.');
        if ($request->user()->role === 'farmOwner' || in_array($request->user()->crm_role, ['admin', 'finance', 'customer_support'], true)) return;

        $permissions = $membership->pivot->permissions === null
            ? $this->defaultPermissions($request->user()->role)
            : json_decode($membership->pivot->permissions, true);
        abort_unless(in_array('viewCrops', $permissions ?? [], true)
            || in_array('manageCrops', $permissions ?? [], true), 403, 'You do not have permission to view crop activities.');
    }

    private function authorizeManage(Request $request, Farm $farm): void
    {
        $membership = $request->user()->farms()->where('farms.id', $farm->id)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');
        abort_if($request->user()->crm_closed_at !== null, 403, 'This CRM account is inactive.');
        if ($request->user()->role === 'farmOwner' || in_array($request->user()->crm_role, ['admin', 'finance'], true)) return;

        $permissions = $membership->pivot->permissions === null
            ? $this->defaultPermissions($request->user()->role)
            : json_decode($membership->pivot->permissions, true);
        abort_unless(in_array('manageCrops', $permissions ?? [], true), 403, 'You do not have permission to manage crop activities.');
    }

    private function assertBelongsToFarm(Farm $farm, CropActivity $activity): void
    {
        abort_if((int) $activity->farm_id !== (int) $farm->id, 404);
    }

    private function defaultPermissions(string $role): array
    {
        return match ($role) {
            'farmManager' => ['viewCrops', 'manageCrops'],
            'farmWorker' => ['viewCrops'],
            default => [],
        };
    }
}
