<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Herd\StoreAnimalRequest;
use App\Http\Requests\Herd\UpdateAnimalRequest;
use App\Http\Resources\Herd\AnimalResource;
use App\Models\Animal;
use App\Models\Farm;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class HerdController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeHerdAccess($request, $farm);

        return response()->json([
            'data' => AnimalResource::collection($farm->animals()->latest()->get()),
        ]);
    }

    public function store(StoreAnimalRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeHerdAccess($request, $farm);

        $data = $request->safe()->except(['image']);
        if ($request->hasFile('image')) {
            $data['image_path'] = $request->file('image')->store(
                "animal-images/{$farm->id}",
                'public',
            );
        }

        try {
            $animal = $farm->animals()->create([
                ...$data,
            'created_by' => $request->user()->id,
            ]);
        } catch (\Throwable $error) {
            if (isset($data['image_path'])) {
                Storage::disk('public')->delete($data['image_path']);
            }
            throw $error;
        }

        return response()->json(['data' => new AnimalResource($animal)], 201);
    }

    public function show(Request $request, Farm $farm, Animal $animal): JsonResponse
    {
        $this->authorizeHerdAccess($request, $farm);
        abort_if($animal->farm_id !== $farm->id, 404);

        return response()->json(['data' => new AnimalResource($animal)]);
    }

    public function update(UpdateAnimalRequest $request, Farm $farm, Animal $animal): JsonResponse
    {
        $this->authorizeHerdAccess($request, $farm);
        abort_if($animal->farm_id !== $farm->id, 404);
        $data = $request->safe()->except(['image']);
        $oldImagePath = $animal->image_path;
        if ($request->hasFile('image')) {
            $data['image_path'] = $request->file('image')->store(
                "animal-images/{$farm->id}",
                'public',
            );
        }

        try {
            $animal->update($data);
        } catch (\Throwable $error) {
            if (isset($data['image_path'])) {
                Storage::disk('public')->delete($data['image_path']);
            }
            throw $error;
        }

        if (isset($data['image_path']) && $oldImagePath !== null) {
            Storage::disk('public')->delete($oldImagePath);
        }

        return response()->json(['data' => new AnimalResource($animal->fresh())]);
    }

    public function destroy(Request $request, Farm $farm, Animal $animal): JsonResponse
    {
        $this->authorizeHerdAccess($request, $farm);
        abort_if($animal->farm_id !== $farm->id, 404);
        $animal->update(['status' => 'deceased']);

        return response()->json(['data' => new AnimalResource($animal->fresh())]);
    }

    private function authorizeHerdAccess(Request $request, Farm $farm): void
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

        if (! in_array('manageHerd', $permissions ?? [], true)) {
            abort(403, 'You do not have permission to manage this herd.');
        }
    }

    private function defaultPermissions(string $role): array
    {
        return match ($role) {
            'farmManager' => ['viewDashboard', 'manageHerd', 'manageBreeding', 'manageFeed', 'viewReports'],
            'farmWorker' => ['viewDashboard', 'manageHerd', 'manageFeed'],
            default => [],
        };
    }
}
