<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\StoreSoilTestRequest;
use App\Models\CropPlot;
use App\Models\Farm;
use App\Models\SoilTest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SoilTestController extends Controller
{
    public function index(Request $request, Farm $farm, CropPlot $cropPlot): JsonResponse
    {
        $this->assertPlot($farm, $cropPlot);
        $this->authorizeAccess($request, $farm, false);

        return response()->json(['data' => $cropPlot->soilTests()->orderByDesc('sampled_at')->get()]);
    }

    public function store(StoreSoilTestRequest $request, Farm $farm, CropPlot $cropPlot): JsonResponse
    {
        $this->assertPlot($farm, $cropPlot);
        $this->authorizeAccess($request, $farm, true);
        $soilTest = $cropPlot->soilTests()->create($request->validated());

        return response()->json(['data' => $soilTest], 201);
    }

    public function update(StoreSoilTestRequest $request, Farm $farm, CropPlot $cropPlot, SoilTest $soilTest): JsonResponse
    {
        $this->assertRecords($farm, $cropPlot, $soilTest);
        $this->authorizeAccess($request, $farm, true);
        $soilTest->update($request->validated());

        return response()->json(['data' => $soilTest->fresh()]);
    }

    public function destroy(Request $request, Farm $farm, CropPlot $cropPlot, SoilTest $soilTest): JsonResponse
    {
        $this->assertRecords($farm, $cropPlot, $soilTest);
        $this->authorizeAccess($request, $farm, true);
        $soilTest->delete();

        return response()->json(null, 204);
    }

    private function assertPlot(Farm $farm, CropPlot $cropPlot): void
    {
        abort_if((int) $cropPlot->farm_id !== (int) $farm->id, 404);
    }

    private function assertRecords(Farm $farm, CropPlot $cropPlot, SoilTest $soilTest): void
    {
        $this->assertPlot($farm, $cropPlot);
        abort_if((int) $soilTest->crop_plot_id !== (int) $cropPlot->id, 404);
    }

    private function authorizeAccess(Request $request, Farm $farm, bool $manage): void
    {
        $membership = $request->user()->farms()->where('farms.id', $farm->id)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');
        abort_if($request->user()->crm_closed_at !== null, 403, 'This CRM account is inactive.');

        if ($request->user()->role === 'farmOwner'
            || in_array($request->user()->crm_role, ['admin', 'finance'], true)) {
            return;
        }

        $permissions = $membership->pivot->permissions === null
            ? match ($request->user()->role) {
                'farmManager' => ['viewCrops', 'manageCrops'],
                'farmWorker' => ['viewCrops'],
                default => [],
            }
            : json_decode($membership->pivot->permissions, true);

        $allowed = $manage
            ? in_array('manageCrops', $permissions ?? [], true)
            : (in_array('viewCrops', $permissions ?? [], true) || in_array('manageCrops', $permissions ?? [], true));

        abort_unless($allowed, 403, $manage
            ? 'You do not have permission to manage soil tests.'
            : 'You do not have permission to view soil tests.');
    }
}
