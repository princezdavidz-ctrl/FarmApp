<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Farm;
use App\Models\VeterinaryRequest;
use App\Models\VeterinarianProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class VeterinaryRequestController extends Controller
{
    public function createForFarm(Request $request, Farm $farm): JsonResponse
    {
        abort_unless(
            $request->user()->farms()->whereKey($farm->id)->exists(),
            403,
            'You do not have access to this farm.',
        );
        $data = $request->validate([
            'county' => ['required', 'string', 'max:100'],
            'animal_type' => ['required', 'string', 'max:100'],
            'animal_name' => ['nullable', 'string', 'max:100'],
            'issue_description' => ['required', 'string', 'max:4000'],
            'location' => ['required', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90', 'required_with:longitude'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180', 'required_with:latitude'],
        ]);
        $vetRequest = VeterinaryRequest::create([
            ...$data,
            'requester_user_id' => $request->user()->id,
            'farm_id' => $farm->id,
            'status' => 'open',
        ]);

        return response()->json(['data' => $this->requestData($vetRequest)], 201);
    }

    public function farmRequests(Request $request, Farm $farm): JsonResponse
    {
        abort_unless(
            $request->user()->farms()->whereKey($farm->id)->exists(),
            403,
            'You do not have access to this farm.',
        );

        return response()->json([
            'data' => VeterinaryRequest::query()
                ->with(['veterinarian.user:id,name,phone', 'farm:id,name,location'])
                ->where('farm_id', $farm->id)
                ->latest()
                ->limit(100)
                ->get()
                ->map(fn (VeterinaryRequest $vetRequest): array => $this->requestData($vetRequest))
                ->values(),
        ]);
    }

    public function availableForVeterinarian(Request $request): JsonResponse
    {
        $profile = $this->activeVeterinarian($request);
        $active = VeterinaryRequest::query()
            ->with(['farm:id,name,location', 'requester:id,name,phone'])
            ->where('veterinarian_profile_id', $profile->id)
            ->where('status', 'accepted')
            ->latest()
            ->first();
        $requests = VeterinaryRequest::query()
            ->with(['farm:id,name,location', 'requester:id,name,phone'])
            ->where('status', 'open')
            ->whereRaw('LOWER(county) = ?', [mb_strtolower($profile->county)])
            ->latest()
            ->limit(100)
            ->get()
            ->map(fn (VeterinaryRequest $vetRequest): array => $this->requestData($vetRequest))
            ->values();

        return response()->json([
            'data' => $active === null ? $requests : [],
            'active_request' => $active === null ? null : $this->requestData($active),
        ]);
    }

    public function accept(Request $request, VeterinaryRequest $veterinaryRequest): JsonResponse
    {
        $profile = $this->activeVeterinarian($request);
        $accepted = DB::transaction(function () use ($profile, $veterinaryRequest): bool {
            $lockedProfile = VeterinarianProfile::query()
                ->whereKey($profile->id)
                ->lockForUpdate()
                ->firstOrFail();
            $lockedRequest = VeterinaryRequest::query()
                ->whereKey($veterinaryRequest->id)
                ->lockForUpdate()
                ->firstOrFail();
            if (VeterinaryRequest::query()
                    ->where('veterinarian_profile_id', $lockedProfile->id)
                    ->where('status', 'accepted')
                    ->exists()
                || $lockedRequest->status !== 'open'
                || mb_strtolower($lockedRequest->county) !== mb_strtolower($lockedProfile->county)) {
                return false;
            }
            $lockedRequest->update([
                'veterinarian_profile_id' => $lockedProfile->id,
                'status' => 'accepted',
            ]);

            return true;
        });
        abort_unless($accepted, 409, 'This request is no longer available or is outside your county.');

        return response()->json([
            'data' => $this->requestData($veterinaryRequest->fresh()->load(['farm:id,name,location', 'requester:id,name,phone'])),
        ]);
    }

    public function updateStatus(Request $request, VeterinaryRequest $veterinaryRequest): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', Rule::in(['cancelled', 'completed'])],
        ]);
        if ($data['status'] === 'cancelled') {
            abort_unless($veterinaryRequest->requester_user_id === $request->user()->id, 404);
            abort_unless($veterinaryRequest->status === 'open', 409, 'Only open requests can be cancelled.');
        } else {
            $profile = $request->user()->veterinarianProfile()->firstOrFail();
            abort_unless(
                $veterinaryRequest->veterinarian_profile_id === $profile->id
                    && $veterinaryRequest->status === 'accepted',
                404,
            );
        }
        $veterinaryRequest->update(['status' => $data['status']]);

        return response()->json([
            'data' => $this->requestData($veterinaryRequest->fresh()->load(['farm:id,name,location', 'requester:id,name,phone', 'veterinarian.user:id,name'])),
        ]);
    }

    private function activeVeterinarian(Request $request): VeterinarianProfile
    {
        $profile = $request->user()->veterinarianProfile()->firstOrFail();
        abort_unless(
            $profile->status === 'approved' && $profile->subscription_expires_at?->isFuture(),
            403,
            'An approved veterinarian account with an active subscription is required.',
        );

        return $profile;
    }

    private function requestData(VeterinaryRequest $vetRequest): array
    {
        return [
            'id' => (string) $vetRequest->id,
            'farm_id' => (string) $vetRequest->farm_id,
            'farm_name' => $vetRequest->farm?->name,
            'requester_name' => $vetRequest->requester?->name,
            'requester_phone' => $vetRequest->requester?->phone,
            'county' => $vetRequest->county,
            'animal_type' => $vetRequest->animal_type,
            'animal_name' => $vetRequest->animal_name,
            'issue_description' => $vetRequest->issue_description,
            'location' => $vetRequest->location,
            'latitude' => $vetRequest->latitude,
            'longitude' => $vetRequest->longitude,
            'status' => $vetRequest->status,
            'veterinarian_name' => $vetRequest->veterinarian?->user?->name,
            'created_at' => $vetRequest->created_at?->toIso8601String(),
        ];
    }
}
