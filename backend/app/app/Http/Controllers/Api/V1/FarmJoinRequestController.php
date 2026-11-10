<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\ReviewFarmJoinRequest;
use App\Http\Requests\Farm\StoreFarmJoinRequest;
use App\Http\Resources\FarmJoinRequestResource;
use App\Models\Farm;
use App\Models\FarmJoinRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FarmJoinRequestController extends Controller
{
    public function mine(Request $request): JsonResponse
    {
        $requests = FarmJoinRequest::with('farm')
            ->where('user_id', $request->user()->id)
            ->latest()
            ->get();

        return response()->json(['data' => FarmJoinRequestResource::collection($requests)]);
    }

    public function store(StoreFarmJoinRequest $request): JsonResponse
    {
        $farm = Farm::where('invite_code', $request->string('invite_code')->toString())->firstOrFail();
        $user = $request->user();

        if ($farm->users()->whereKey($user->id)->exists()) {
            return response()->json(['message' => 'You are already a member of this farm.'], 422);
        }

        $pending = FarmJoinRequest::where('farm_id', $farm->id)
            ->where('user_id', $user->id)
            ->where('status', 'pending')
            ->exists();
        if ($pending) {
            return response()->json(['message' => 'A request for this farm is already pending.'], 422);
        }

        $joinRequest = FarmJoinRequest::create([
            'farm_id' => $farm->id,
            'user_id' => $user->id,
            'requested_role' => $user->role,
            'status' => 'pending',
            'message' => $request->validated('message'),
        ]);

        return response()->json(['data' => new FarmJoinRequestResource($joinRequest->load('farm'))], 201);
    }

    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeOwner($request, $farm);
        $requests = $farm->joinRequests()->with('user')->latest()->get();

        return response()->json(['data' => FarmJoinRequestResource::collection($requests)]);
    }

    public function review(ReviewFarmJoinRequest $request, Farm $farm, FarmJoinRequest $farmJoinRequest): JsonResponse
    {
        $this->authorizeOwner($request, $farm);
        abort_if($farmJoinRequest->farm_id !== $farm->id, 404);

        $updated = DB::transaction(function () use ($request, $farmJoinRequest) {
            $joinRequest = FarmJoinRequest::query()->lockForUpdate()->findOrFail($farmJoinRequest->id);
            abort_if($joinRequest->status !== 'pending', 422, 'This request has already been reviewed.');

            if ($request->string('action')->toString() === 'accept') {
                $joinRequest->farm->users()->syncWithoutDetaching([$joinRequest->user_id]);
                $joinRequest->status = 'accepted';
            } else {
                $joinRequest->status = 'rejected';
            }

            $joinRequest->reviewed_by = $request->user()->id;
            $joinRequest->reviewed_at = now();
            $joinRequest->save();
            return $joinRequest;
        });

        return response()->json(['data' => new FarmJoinRequestResource($updated->load(['farm', 'user']))]);
    }

    private function authorizeOwner(Request $request, Farm $farm): void
    {
        $isOwner = $request->user()->role === 'farmOwner'
            && $request->user()->farms()->whereKey($farm->id)->exists();
        abort_unless($isOwner, 403, 'Only the farm owner can review join requests.');
    }
}