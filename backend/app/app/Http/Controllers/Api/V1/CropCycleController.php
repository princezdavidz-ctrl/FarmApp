<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\StoreCropCycleRequest;
use App\Http\Requests\Farm\UpdateCropCycleRequest;
use App\Models\CropCycle;
use App\Models\Farm;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CropCycleController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeView($request, $farm);
        $cycles = $farm->cropCycles()
            ->withSum('activities as activity_cost_kes', 'cost')
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = $request->string('search')->toString();
                $query->where(fn ($items) => $items->where('crop_name', 'like', "%{$search}%")
                    ->orWhere('plot_name', 'like', "%{$search}%")
                    ->orWhere('variety', 'like', "%{$search}%"));
            })
            ->orderByRaw("CASE WHEN status IN ('harvested', 'failed') THEN 1 ELSE 0 END")
            ->orderBy('expected_harvest_date')
            ->latest('planting_date')
            ->get();

        $cycles->each(function (CropCycle $cycle): void {
            $cost = round((float) ($cycle->activity_cost_kes ?? 0), 2);
            $cycle->setAttribute('activity_cost_kes', $cost);
            $cycle->setAttribute(
                'gross_profit_kes',
                $cycle->actual_revenue_kes === null
                    ? null
                    : round((float) $cycle->actual_revenue_kes - $cost, 2),
            );
            $cycle->setAttribute(
                'yield_kg_per_acre',
                (float) $cycle->area_acres > 0 && $cycle->actual_yield_kg !== null
                    ? round((float) $cycle->actual_yield_kg / (float) $cycle->area_acres, 2)
                    : null,
            );
        });

        return response()->json(['data' => $cycles]);
    }

    public function store(StoreCropCycleRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeManage($request, $farm);
        $cycle = $farm->cropCycles()->create($request->validated());

        return response()->json(['data' => $cycle], 201);
    }

    public function update(UpdateCropCycleRequest $request, Farm $farm, CropCycle $cropCycle): JsonResponse
    {
        $this->assertBelongsToFarm($farm, $cropCycle);
        $this->authorizeManage($request, $farm);
        $cropCycle->update($request->validated());

        return response()->json(['data' => $cropCycle->fresh()]);
    }

    public function destroy(Request $request, Farm $farm, CropCycle $cropCycle): JsonResponse
    {
        $this->assertBelongsToFarm($farm, $cropCycle);
        $this->authorizeManage($request, $farm);
        $cropCycle->delete();

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
            || in_array('manageCrops', $permissions ?? [], true), 403, 'You do not have permission to view crop records.');
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
        abort_unless(in_array('manageCrops', $permissions ?? [], true), 403, 'You do not have permission to manage crop records.');
    }

    private function assertBelongsToFarm(Farm $farm, CropCycle $cropCycle): void
    {
        abort_if((int) $cropCycle->farm_id !== (int) $farm->id, 404);
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
