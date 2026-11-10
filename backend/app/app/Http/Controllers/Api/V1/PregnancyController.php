<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Breeding\StorePregnancyRequest;
use App\Http\Requests\Breeding\UpdatePregnancyRequest;
use App\Http\Resources\Breeding\PregnancyResource;
use App\Models\Animal;
use App\Models\Farm;
use App\Models\Pregnancy;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class PregnancyController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeBreedingAccess($request, $farm);

        $query = $farm->pregnancies()->with(['sow', 'boar'])->latest('expected_farrowing_date');
        if ($request->filled('status')) {
            $query->where('status', $request->string('status')->toString());
        }

        return response()->json(['data' => PregnancyResource::collection($query->get())]);
    }

    public function store(StorePregnancyRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeBreedingAccess($request, $farm);
        $data = $request->validated();
        $this->assertAnimalBelongsToFarm($farm, (int) $data['sow_id'], 'sow');
        if (! empty($data['boar_id'])) {
            $this->assertAnimalBelongsToFarm($farm, (int) $data['boar_id'], 'boar');
        }

        $data['expected_farrowing_date'] ??= Carbon::parse($data['mating_date'])
            ->addDays(114)->toDateString();
        $data['created_by'] = $request->user()->id;

        $pregnancy = $farm->pregnancies()->create($data);

        return response()->json([
            'data' => new PregnancyResource($pregnancy->load(['sow', 'boar'])),
        ], 201);
    }

    public function show(Request $request, Farm $farm, Pregnancy $pregnancy): JsonResponse
    {
        $this->authorizeBreedingAccess($request, $farm);
        $this->assertPregnancyBelongsToFarm($farm, $pregnancy);

        return response()->json([
            'data' => new PregnancyResource($pregnancy->load(['sow', 'boar'])),
        ]);
    }

    public function update(
        UpdatePregnancyRequest $request,
        Farm $farm,
        Pregnancy $pregnancy,
    ): JsonResponse {
        $this->authorizeBreedingAccess($request, $farm);
        $this->assertPregnancyBelongsToFarm($farm, $pregnancy);
        $data = $request->validated();

        if (array_key_exists('boar_id', $data) && $data['boar_id'] !== null) {
            $this->assertAnimalBelongsToFarm($farm, (int) $data['boar_id'], 'boar');
        }
        $pregnancy->update($data);

        return response()->json([
            'data' => new PregnancyResource($pregnancy->fresh()->load(['sow', 'boar'])),
        ]);
    }

    public function destroy(Request $request, Farm $farm, Pregnancy $pregnancy): JsonResponse
    {
        $this->authorizeBreedingAccess($request, $farm);
        $this->assertPregnancyBelongsToFarm($farm, $pregnancy);
        $pregnancy->update(['status' => 'aborted']);

        return response()->json([
            'data' => new PregnancyResource($pregnancy->fresh()->load(['sow', 'boar'])),
        ]);
    }

    private function assertAnimalBelongsToFarm(Farm $farm, int $animalId, string $role): void
    {
        $animal = $farm->animals()->whereKey($animalId)->first();
        abort_if($animal === null, 422, "The {$role} does not belong to this farm.");
        if ($role === 'sow' && $animal->sex !== 'female') {
            throw ValidationException::withMessages([
                'sow_id' => ['Select a female pig.'],
            ]);
        }
    }

    private function assertPregnancyBelongsToFarm(Farm $farm, Pregnancy $pregnancy): void
    {
        abort_if($pregnancy->farm_id !== $farm->id, 404);
    }

    private function authorizeBreedingAccess(Request $request, Farm $farm): void
    {
        $user = $request->user();
        $membership = $user->farms()->where('farms.id', $farm->id)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');

        if ($user->role === 'farmOwner') return;

        $permissions = $membership->pivot->permissions === null
            ? match ($user->role) {
                'farmManager' => ['viewDashboard', 'manageHerd', 'manageBreeding', 'manageFeed', 'viewReports'],
                default => [],
            }
            : json_decode($membership->pivot->permissions, true);

        abort_unless(in_array('manageBreeding', $permissions ?? [], true), 403,
            'You do not have permission to manage breeding.');
    }
}