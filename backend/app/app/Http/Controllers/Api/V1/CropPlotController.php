<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\StoreCropPlotRequest;
use App\Http\Requests\Farm\UpdateCropPlotRequest;
use App\Models\CropPlot;
use App\Models\Farm;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CropPlotController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeView($request, $farm);

        $plots = $farm->cropPlots()
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')->toString()))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = $request->string('search')->toString();
                $query->where(fn ($items) => $items
                    ->where('name', 'like', "%{$search}%")
                    ->orWhere('soil_type', 'like', "%{$search}%"));
            })
            ->orderBy('name')
            ->get();

        return response()->json(['data' => $plots]);
    }

    public function store(StoreCropPlotRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeManage($request, $farm);
        $plot = $farm->cropPlots()->create($request->validated());

        return response()->json(['data' => $plot], 201);
    }

    public function update(UpdateCropPlotRequest $request, Farm $farm, CropPlot $cropPlot): JsonResponse
    {
        $this->assertBelongsToFarm($farm, $cropPlot);
        $this->authorizeManage($request, $farm);
        $cropPlot->update($request->validated());

        return response()->json(['data' => $cropPlot->fresh()]);
    }

    public function destroy(Request $request, Farm $farm, CropPlot $cropPlot): JsonResponse
    {
        $this->assertBelongsToFarm($farm, $cropPlot);
        $this->authorizeManage($request, $farm);
        $cropPlot->delete();

        return response()->json(null, 204);
    }

    private function authorizeView(Request $request, Farm $farm): void
    {
        $membership = $request->user()->farms()->where('farms.id', $farm->id)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');
        abort_if($request->user()->crm_closed_at !== null, 403, 'This CRM account is inactive.');
        if ($request->user()->role === 'farmOwner'
            || in_array($request->user()->crm_role, ['admin', 'finance', 'customer_support'], true)) {
            return;
        }

        $permissions = $membership->pivot->permissions === null
            ? $this->defaultPermissions($request->user()->role)
            : json_decode($membership->pivot->permissions, true);

        abort_unless(
            in_array('viewCrops', $permissions ?? [], true)
                || in_array('manageCrops', $permissions ?? [], true),
            403,
            'You do not have permission to view crop plots.',
        );
    }

    private function authorizeManage(Request $request, Farm $farm): void
    {
        $membership = $request->user()->farms()->where('farms.id', $farm->id)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');
        abort_if($request->user()->crm_closed_at !== null, 403, 'This CRM account is inactive.');
        if ($request->user()->role === 'farmOwner'
            || in_array($request->user()->crm_role, ['admin', 'finance'], true)) {
            return;
        }

        $permissions = $membership->pivot->permissions === null
            ? $this->defaultPermissions($request->user()->role)
            : json_decode($membership->pivot->permissions, true);

        abort_unless(
            in_array('manageCrops', $permissions ?? [], true),
            403,
            'You do not have permission to manage crop plots.',
        );
    }

    private function assertBelongsToFarm(Farm $farm, CropPlot $cropPlot): void
    {
        abort_if((int) $cropPlot->farm_id !== (int) $farm->id, 404);
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
