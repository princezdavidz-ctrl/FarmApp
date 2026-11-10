<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\StoreFarmRequest;
use App\Http\Resources\FarmResource;
use App\Models\Farm;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FarmController extends Controller
{
    public function store(StoreFarmRequest $request): JsonResponse
    {
        $user = $request->user();
        $farm = DB::transaction(function () use ($request, $user): Farm {
            $user->newQuery()->whereKey($user->id)->lockForUpdate()->firstOrFail();
            abort_if(
                Farm::query()->where('created_by', $user->id)->exists()
                    || ($user->role === 'farmOwner' && $user->farms()->exists()),
                409,
                'Each account can register only one farm. You can still join other farms as staff.',
            );

            return $user->farms()->create([
                ...$request->validated(),
                'created_by' => $user->id,
                'farming_type' => $request->validated('farming_type', 'mixed'),
                'production_types' => $request->validated('production_types', []),
            ]);
        });

        return response()->json(['data' => new FarmResource($farm)], 201);
    }

    public function update(Request $request, Farm $farm): JsonResponse
    {
        abort_unless($request->user()->farms()->where('farms.id', $farm->getKey())->exists(), 403);
        abort_if($request->exists('name'), 422, 'Farm name changes must be submitted for CRM approval.');
        abort_unless(
            $request->user()->role === 'farmOwner' ||
                ($request->user()->crm_role ?? null) === 'admin',
            403,
            'Only farm owners and CRM administrators can update farm settings.',
        );

        $farm->update($request->validate([
            'location' => ['sometimes', 'nullable', 'string', 'max:255'],
            'latitude' => ['sometimes', 'nullable', 'numeric', 'between:-90,90', 'required_with:longitude'],
            'longitude' => ['sometimes', 'nullable', 'numeric', 'between:-180,180', 'required_with:latitude'],
        ]));

        return response()->json(['data' => new FarmResource($farm->fresh())]);
    }
}
