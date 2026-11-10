<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Health\StoreHealthRecordRequest;
use App\Http\Requests\Health\UpdateHealthRecordRequest;
use App\Http\Resources\Health\HealthRecordResource;
use App\Models\Farm;
use App\Models\HealthRecord;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HealthController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeHealthAccess($request, $farm);

        $query = $farm->healthRecords()->with('animal:id,tag');

        // Filter by type if provided
        if ($request->has('type')) {
            $query->where('type', $request->query('type'));
        }

        // Filter by status if provided
        if ($request->has('status')) {
            $query->where('status', $request->query('status'));
        }

        $records = $query->latest()->get();

        return response()->json([
            'data' => HealthRecordResource::collection($records),
        ]);
    }

    public function store(StoreHealthRecordRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeHealthAccess($request, $farm, write: true);

        $data = $request->validated();
        if (! isset($data['animal_id'])) {
            $data['animal_id'] = $this->resolveAnimalId($farm, $data['pig_id'] ?? '');
        }
        unset($data['pig_id']);

        $record = $farm->healthRecords()->create([
            ...$data,
            'created_by' => $request->user()->id,
        ])->load('animal:id,tag');

        return response()->json(['data' => new HealthRecordResource($record)], 201);
    }

    public function show(Request $request, Farm $farm, HealthRecord $healthRecord): JsonResponse
    {
        $this->authorizeHealthAccess($request, $farm);
        abort_if($healthRecord->farm_id !== $farm->id, 404);

        return response()->json(['data' => new HealthRecordResource($healthRecord->load('animal:id,tag'))]);
    }

    public function update(UpdateHealthRecordRequest $request, Farm $farm, HealthRecord $healthRecord): JsonResponse
    {
        $this->authorizeHealthAccess($request, $farm, write: true);
        abort_if($healthRecord->farm_id !== $farm->id, 404);

        $data = $request->validated();
        if (array_key_exists('pig_id', $data)) {
            $data['animal_id'] = $this->resolveAnimalId($farm, $data['pig_id'] ?? '');
        }
        unset($data['pig_id']);
        $healthRecord->update($data);

        return response()->json(['data' => new HealthRecordResource($healthRecord->fresh()->load('animal:id,tag'))]);
    }

    public function destroy(Request $request, Farm $farm, HealthRecord $healthRecord): JsonResponse
    {
        $this->authorizeHealthAccess($request, $farm, write: true);
        abort_if($healthRecord->farm_id !== $farm->id, 404);

        $healthRecord->delete();

        return response()->json(null, 204);
    }

    /**
     * Get health alerts for critical cases
     */
    public function getAlerts(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeHealthAccess($request, $farm);

        $alerts = $farm->healthRecords()
            ->where(function ($query) {
                $query->whereIn('status', ['critical', 'recovering'])
                    ->orWhere('type', 'mortality');
            })
            ->latest()
            ->get();

        return response()->json([
            'data' => HealthRecordResource::collection($alerts),
        ]);
    }

    /**
     * Get health analytics for the farm
     */
    public function getAnalytics(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeHealthAccess($request, $farm);

        $totalRecords = $farm->healthRecords()->count();
        $healthyAnimals = $farm->animals()->where('status', 'active')->count();
        $sickAnimals = $farm->healthRecords()
            ->whereIn('status', ['critical', 'recovering'])
            ->distinct('animal_id')
            ->count('animal_id');
        $vaccinationsDue = $farm->healthRecords()
            ->where('type', 'vaccination')
            ->where('status', 'due')
            ->count();
        $underTreatment = $farm->healthRecords()
            ->where('type', 'treatment')
            ->where('status', 'recovering')
            ->distinct('animal_id')
            ->count('animal_id');
        $deceasedAnimals = $farm->healthRecords()
            ->where('type', 'mortality')
            ->count();
        $totalAnimals = $farm->animals()->count();
        $mortalityRate = $totalAnimals > 0 ? round(($deceasedAnimals / $totalAnimals) * 100, 2) : 0;
        $vaccinationRate = $totalAnimals > 0 ? round(($vaccinationsDue / $totalAnimals) * 100, 2) : 0;

        return response()->json([
            'data' => [
                'healthy_count' => $healthyAnimals,
                'sick_count' => $sickAnimals,
                'vaccinations_due' => $vaccinationsDue,
                'under_treatment' => $underTreatment,
                'total_records' => $totalRecords,
                'deceased_animals' => $deceasedAnimals,
                'mortality_rate' => $mortalityRate,
                'vaccination_rate' => $vaccinationRate,
                'total_animals' => $totalAnimals,
            ],
        ]);
    }

    private function authorizeHealthAccess(Request $request, Farm $farm, bool $write = false): void
    {
        $user = $request->user();
        $membership = $user->farms()->where('farms.id', $farm->id)->first();

        if ($membership === null) {
            abort(403, 'You do not have access to this farm.');
        }

        if ($user->role === 'farmOwner') {
            return;
        }

        $permissions = $membership->pivot->permissions === null
            ? $this->defaultPermissions($user->role)
            : json_decode($membership->pivot->permissions, true);

        $canManage = in_array('manageHealth', $permissions ?? [], true);
        $canView = $canManage || in_array('viewHealth', $permissions ?? [], true);
        if ($write ? ! $canManage : ! $canView) {
            abort(403, $write
                ? 'You do not have permission to manage health records.'
                : 'You do not have permission to view health records.');
        }
    }

    private function resolveAnimalId(Farm $farm, string $identifier): int
    {
        $animal = $farm->animals()->where('tag', $identifier)->first();
        if ($animal === null && ctype_digit($identifier)) {
            $animal = $farm->animals()->whereKey((int) $identifier)->first();
        }

        if ($animal === null) {
            abort(422, 'The selected pig does not belong to this farm.');
        }

        return (int) $animal->id;
    }

    private function defaultPermissions(string $role): array
    {
        return match ($role) {
            'farmManager' => ['manageHerd', 'manageFeed', 'viewHealth', 'manageHealth', 'viewReports'],
            'veterinarian' => ['viewHerd', 'manageHealth'],
            'farmWorker' => ['viewHerd', 'viewHealth'],
            default => [],
        };
    }
}
