<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\UpdateFarmMemberRequest;
use App\Http\Resources\FarmMemberResource;
use App\Models\Farm;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FarmMemberController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeMember($request, $farm);

        return response()->json(['data' => FarmMemberResource::collection($farm->users)]);
    }

    public function update(UpdateFarmMemberRequest $request, Farm $farm, User $user): JsonResponse
    {
        $this->authorizeOwner($request, $farm);
        $isFarmMember = $farm->users()->where('users.id', $user->id)->exists();

        if (! $isFarmMember || $user->role === 'farmOwner') {
            abort(404, 'Farm member not found.');
        }

        $farm->users()->updateExistingPivot($user->id, [
            'permissions' => json_encode($request->validated('permissions')),
        ]);

        return response()->json(['data' => new FarmMemberResource($farm->users()->findOrFail($user->id))]);
    }

    public function destroy(Request $request, Farm $farm, User $user): JsonResponse
    {
        $this->authorizeOwner($request, $farm);
        $isFarmMember = $farm->users()->where('users.id', $user->id)->exists();

        if (! $isFarmMember || $user->role === 'farmOwner') {
            abort(404, 'Farm member not found.');
        }

        $farm->users()->detach($user->id);

        return response()->json(['message' => 'Farm member removed.']);
    }

    private function authorizeMember(Request $request, Farm $farm): void
    {
        $belongs = $request->user()->farms()->where('farms.id', $farm->id)->exists();

        if (! $belongs) {
            abort(403, 'You do not have access to this farm.');
        }
    }

    private function authorizeOwner(Request $request, Farm $farm): void
    {
        $isOwner = $request->user()->role === 'farmOwner'
            && $request->user()->farms()->where('farms.id', $farm->id)->exists();

        if (! $isOwner) {
            abort(403, 'Only the farm owner can manage member policies.');
        }
    }
}
