<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\DriverProfile;
use App\Models\Farm;
use App\Models\SupplierProfile;
use App\Models\TransportRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class TransportRequestController extends Controller
{
    public function createForFarm(Request $request, Farm $farm): JsonResponse
    {
        abort_unless(
            $request->user()->farms()->whereKey($farm->id)->exists(),
            403,
            'You do not have access to this farm.',
        );

        return $this->create($request, ['farm_id' => $farm->id]);
    }

    public function createForSupplier(Request $request): JsonResponse
    {
        $profile = $request->user()->supplierProfile()->firstOrFail();
        abort_unless(
            $profile->status === 'approved' && $profile->subscription_expires_at?->isFuture(),
            403,
            'An approved supplier account with an active subscription is required.',
        );

        return $this->create($request, ['supplier_profile_id' => $profile->id]);
    }

    public function farmRequests(Request $request, Farm $farm): JsonResponse
    {
        abort_unless(
            $request->user()->farms()->whereKey($farm->id)->exists(),
            403,
            'You do not have access to this farm.',
        );

        return $this->requestList(
            TransportRequest::query()->where('farm_id', $farm->id),
        );
    }

    public function supplierRequests(Request $request): JsonResponse
    {
        $profile = $request->user()->supplierProfile()->firstOrFail();

        return $this->requestList(
            TransportRequest::query()->where('supplier_profile_id', $profile->id),
        );
    }

    public function availableForDriver(Request $request): JsonResponse
    {
        $driver = $this->activeDriver($request);
        $activeRequest = TransportRequest::query()
            ->with(['requester:id,name,phone', 'driver.user:id,name,phone'])
            ->where('driver_profile_id', $driver->id)
            ->where('status', 'accepted')
            ->latest()
            ->first();
        $isOnline = $driver->available
            && $driver->location_updated_at?->greaterThanOrEqualTo(now()->subMinutes(15));
        $requests = collect();

        if ($isOnline && $activeRequest === null) {
            $requests = TransportRequest::query()
                ->with(['requester:id,name,phone', 'driver.user:id,name,phone'])
                ->where('status', 'open')
                ->where('vehicle_type', $driver->vehicle_type)
                ->whereIn('service_type', explode(',', $driver->service_types))
                ->latest()
                ->get()
                ->filter(fn (TransportRequest $transportRequest): bool =>
                    $this->distanceKm(
                        (float) $driver->latitude,
                        (float) $driver->longitude,
                        (float) $transportRequest->pickup_latitude,
                        (float) $transportRequest->pickup_longitude,
                    ) <= $transportRequest->radius_km
                )
                ->map(fn (TransportRequest $transportRequest): array =>
                    $this->requestData(
                        $transportRequest,
                        $this->distanceKm(
                            (float) $driver->latitude,
                            (float) $driver->longitude,
                            (float) $transportRequest->pickup_latitude,
                            (float) $transportRequest->pickup_longitude,
                        ),
                    )
                )
                ->values();
        }

        return response()->json([
            'data' => $requests,
            'active_request' => $activeRequest === null
                ? null
                : $this->requestData($activeRequest),
        ]);
    }

    public function accept(Request $request, TransportRequest $transportRequest): JsonResponse
    {
        $driver = $this->activeDriver($request);
        abort_unless(
            $driver->available && $driver->location_updated_at?->greaterThanOrEqualTo(now()->subMinutes(15)),
            409,
            'Go online and share a recent location before accepting a request.',
        );

        $accepted = DB::transaction(function () use ($driver, $transportRequest): bool {
            $lockedDriver = DriverProfile::query()
                ->whereKey($driver->id)
                ->lockForUpdate()
                ->firstOrFail();
            $lockedRequest = TransportRequest::query()
                ->whereKey($transportRequest->id)
                ->lockForUpdate()
                ->firstOrFail();
            if (! $lockedDriver->available
                || ! $lockedDriver->location_updated_at?->greaterThanOrEqualTo(now()->subMinutes(15))
                || TransportRequest::query()
                    ->where('driver_profile_id', $lockedDriver->id)
                    ->where('status', 'accepted')
                    ->exists()
                || $lockedRequest->status !== 'open'
                || $lockedRequest->vehicle_type !== $lockedDriver->vehicle_type
                || ! in_array($lockedRequest->service_type, explode(',', $lockedDriver->service_types), true)
                || $this->distanceKm(
                    (float) $lockedDriver->latitude,
                    (float) $lockedDriver->longitude,
                    (float) $lockedRequest->pickup_latitude,
                    (float) $lockedRequest->pickup_longitude,
                ) > $lockedRequest->radius_km) {
                return false;
            }

            $lockedRequest->update([
                'driver_profile_id' => $lockedDriver->id,
                'status' => 'accepted',
            ]);

            return true;
        });

        abort_unless($accepted, 409, 'This request is no longer available or does not match your vehicle and location.');

        return response()->json([
            'data' => $this->requestData($transportRequest->fresh()->load('driver.user:id,name,phone')),
        ]);
    }

    public function updateStatus(Request $request, TransportRequest $transportRequest): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', Rule::in(['cancelled', 'in_transit', 'arrived', 'completed'])],
        ]);
        if ($data['status'] === 'completed') {
            $data += $request->validate([
                'delivery_confirmation' => ['required', 'string', 'min:3', 'max:1000'],
            ]);
        }

        $user = $request->user();
        if ($data['status'] === 'cancelled') {
            abort_unless($transportRequest->requester_user_id === $user->id, 404);
            abort_unless($transportRequest->status === 'open', 409, 'Only open requests can be cancelled.');
            $updates = ['status' => 'cancelled'];
        } else {
            $driver = $user->driverProfile()->firstOrFail();
            abort_unless($transportRequest->driver_profile_id === $driver->id, 404);
            $allowedPreviousStatuses = match ($data['status']) {
                'in_transit' => ['accepted'],
                'arrived' => ['in_transit'],
                'completed' => ['arrived'],
                default => [],
            };
            abort_unless(
                in_array($transportRequest->status, $allowedPreviousStatuses, true),
                409,
                'The delivery must follow accepted, in transit, arrived, then completed.',
            );

            $updates = ['status' => $data['status']];
            if ($data['status'] === 'arrived') {
                $updates['arrived_at'] = now();
            }
            if ($data['status'] === 'completed') {
                $updates['completed_at'] = now();
                $updates['delivery_confirmation'] = $data['delivery_confirmation'];
            }
        }
        $transportRequest->update($updates);

        return response()->json(['data' => $this->requestData($transportRequest->fresh())]);
    }

    private function create(Request $request, array $owner): JsonResponse
    {
        $data = $request->validate([
            'service_type' => ['required', Rule::in(['herd', 'supplies'])],
            'vehicle_type' => ['required', 'string', 'max:100'],
            'pickup_latitude' => ['required', 'numeric', 'between:-90,90'],
            'pickup_longitude' => ['required', 'numeric', 'between:-180,180'],
            'pickup_address' => ['required', 'string', 'max:255'],
            'destination_latitude' => ['required', 'numeric', 'between:-90,90'],
            'destination_longitude' => ['required', 'numeric', 'between:-180,180'],
            'destination_address' => ['required', 'string', 'max:255'],
            'load_description' => ['nullable', 'string', 'max:255'],
            'radius_km' => ['sometimes', 'integer', 'min:1', 'max:100'],
            'pig_inquiry_id' => ['nullable', 'integer', 'exists:pig_inquiries,id'],
        ]);
        $inquiryId = $data['pig_inquiry_id'] ?? null;
        unset($data['pig_inquiry_id']);
        if ($inquiryId !== null) {
            abort_unless(isset($owner['farm_id']), 422, 'Only a farm transport request can be linked to a buyer inquiry.');
            $inquiry = \App\Models\PigInquiry::query()->with('listing')->findOrFail($inquiryId);
            abort_unless(
                $inquiry->status === 'accepted'
                    && (int) $inquiry->listing?->farm_id === (int) $owner['farm_id']
                    && ! $inquiry->transportRequest()->exists(),
                409,
                'The buyer inquiry must be accepted by this farm and must not already have transport assigned.',
            );
        }
        $transportRequest = TransportRequest::create([
            ...$data,
            ...$owner,
            'requester_user_id' => $request->user()->id,
            'radius_km' => $data['radius_km'] ?? 25,
            'status' => 'open',
            'pig_inquiry_id' => $inquiryId,
        ]);

        return response()->json(['data' => $this->requestData($transportRequest)], 201);
    }

    private function requestList($query): JsonResponse
    {
        return response()->json([
            'data' => $query->with(['requester:id,name,phone', 'driver.user:id,name,phone'])->latest()->limit(100)->get()
                ->map(fn (TransportRequest $transportRequest): array => $this->requestData($transportRequest)),
        ]);
    }

    private function activeDriver(Request $request): DriverProfile
    {
        $driver = $request->user()->driverProfile()->firstOrFail();
        abort_unless(
            $driver->status === 'approved' && $driver->subscription_expires_at?->isFuture(),
            403,
            'An approved driver account with an active subscription is required.',
        );

        return $driver;
    }

    private function requestData(TransportRequest $transportRequest, ?float $distance = null): array
    {
        $requester = $transportRequest->requester;
        $driver = $transportRequest->driver?->user;

        return [
            'id' => (string) $transportRequest->id,
            'service_type' => $transportRequest->service_type,
            'vehicle_type' => $transportRequest->vehicle_type,
            'pickup_latitude' => $transportRequest->pickup_latitude,
            'pickup_longitude' => $transportRequest->pickup_longitude,
            'pickup_address' => $transportRequest->pickup_address,
            'destination_latitude' => $transportRequest->destination_latitude,
            'destination_longitude' => $transportRequest->destination_longitude,
            'destination_address' => $transportRequest->destination_address,
            'load_description' => $transportRequest->load_description,
            'radius_km' => $transportRequest->radius_km,
            'distance_km' => $distance === null ? null : round($distance, 1),
            'status' => $transportRequest->status,
            'arrived_at' => $transportRequest->arrived_at?->toIso8601String(),
            'completed_at' => $transportRequest->completed_at?->toIso8601String(),
            'delivery_confirmation' => $transportRequest->delivery_confirmation,
            'pig_inquiry_id' => $transportRequest->pig_inquiry_id === null ? null : (string) $transportRequest->pig_inquiry_id,
            'driver_latitude' => in_array($transportRequest->status, ['accepted', 'in_transit'], true)
                && $transportRequest->driver?->location_updated_at?->greaterThanOrEqualTo(now()->subMinutes(5))
                    ? $transportRequest->driver->latitude
                    : null,
            'driver_longitude' => in_array($transportRequest->status, ['accepted', 'in_transit'], true)
                && $transportRequest->driver?->location_updated_at?->greaterThanOrEqualTo(now()->subMinutes(5))
                    ? $transportRequest->driver->longitude
                    : null,
            'driver_location_updated_at' => in_array($transportRequest->status, ['accepted', 'in_transit'], true)
                && $transportRequest->driver?->location_updated_at?->greaterThanOrEqualTo(now()->subMinutes(5))
                    ? $transportRequest->driver->location_updated_at?->toIso8601String()
                    : null,
            'created_at' => $transportRequest->created_at?->toIso8601String(),
            'driver_profile_id' => $transportRequest->driver_profile_id === null
                ? null
                : (string) $transportRequest->driver_profile_id,
            'requester_name' => $requester?->name,
            'requester_phone' => $requester?->phone,
            'driver_name' => $driver?->name,
            'driver_phone' => $driver?->phone,
        ];
    }

    private function distanceKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $deltaLat = deg2rad($lat2 - $lat1);
        $deltaLng = deg2rad($lng2 - $lng1);

        return 6371 * 2 * asin(sqrt(
            pow(sin($deltaLat / 2), 2)
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2))
            * pow(sin($deltaLng / 2), 2),
        ));
    }
}
