<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Growth\StoreGrowthRecordRequest;
use App\Http\Requests\Growth\UpdateGrowthRecordRequest;
use App\Http\Resources\Growth\GrowthRecordResource;
use App\Models\Farm;
use App\Models\GrowthRecord;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class GrowthController extends Controller
{
    /** @return AnonymousResourceCollection */
    public function index(Request $request, Farm $farm): AnonymousResourceCollection
    {
        $this->authorizeGrowthAccess($request, $farm, 'viewGrowth');

        $query = $farm->growthRecords();

        if ($request->has('search')) {
            $query->whereHas('animal', function ($q) {
                $q->where('identifier', 'like', '%' . request('search') . '%');
            });
        }

        if ($request->has('period')) {
            $days = match ($request->period) {
                '7days' => 7,
                '30days' => 30,
                '90days' => 90,
                '1year' => 365,
                default => 30,
            };
            $query->where('measurement_date', '>=', now()->subDays($days));
        }

        $records = $query->orderBy('measurement_date', 'desc')->paginate(20);

        return GrowthRecordResource::collection($records);
    }

    public function store(StoreGrowthRecordRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeGrowthAccess($request, $farm, 'manageGrowth');

        $record = $farm->growthRecords()->create([
            ...$request->validated(),
            'created_by' => $request->user()->id,
        ]);

        return response()->json(
            new GrowthRecordResource($record),
            201
        );
    }

    public function show(Request $request, Farm $farm, GrowthRecord $growthRecord): GrowthRecordResource
    {
        $this->authorizeGrowthAccess($request, $farm, 'viewGrowth');

        if ($growthRecord->farm_id !== $farm->id) {
            abort(404);
        }

        return new GrowthRecordResource($growthRecord);
    }

    public function update(UpdateGrowthRecordRequest $request, Farm $farm, GrowthRecord $growthRecord): GrowthRecordResource
    {
        $this->authorizeGrowthAccess($request, $farm, 'manageGrowth');

        if ($growthRecord->farm_id !== $farm->id) {
            abort(404);
        }

        $growthRecord->update($request->validated());

        return new GrowthRecordResource($growthRecord);
    }

    public function destroy(Request $request, Farm $farm, GrowthRecord $growthRecord): JsonResponse
    {
        $this->authorizeGrowthAccess($request, $farm, 'manageGrowth');

        if ($growthRecord->farm_id !== $farm->id) {
            abort(404);
        }

        $growthRecord->delete();

        return response()->json(null, 204);
    }

    public function getOverview(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeGrowthAccess($request, $farm, 'viewGrowth');

        $records = $farm->growthRecords()
            ->orderBy('measurement_date', 'desc')
            ->get();

        if ($records->isEmpty()) {
            return response()->json([
                'average_weight' => 0,
                'fastest_growing_id' => null,
                'weekly_gain' => 0,
                'target_achievement' => 0,
                'total_animals' => 0,
            ]);
        }

        // Average weight
        $averageWeight = $records->avg('current_weight');

        // Fastest growing (highest daily_gain)
        $fastestGrowing = $records->where('daily_gain')->sortByDesc('daily_gain')->first();
        $fastestGrowingId = $fastestGrowing?->animal->identifier;

        // Weekly gain (average)
        $weeklyGain = $records->where('weight_gain')->avg('weight_gain') * 7;

        // Target achievement percentage
        $targetRecords = $records->where('target_weight');
        $targetAchievement = $targetRecords->isEmpty()
            ? 0
            : ($targetRecords->sum('current_weight') / $targetRecords->sum('target_weight')) * 100;

        $totalAnimals = $farm->animals()->count();

        return response()->json([
            'average_weight' => round($averageWeight, 2),
            'fastest_growing_id' => $fastestGrowingId,
            'weekly_gain' => round($weeklyGain, 2),
            'target_achievement' => round(min($targetAchievement, 100), 2),
            'total_animals' => $totalAnimals,
        ]);
    }

    public function getAnalytics(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeGrowthAccess($request, $farm, 'viewGrowth');

        $days = match ($request->period ?? '30days') {
            '7days' => 7,
            '30days' => 30,
            '90days' => 90,
            '1year' => 365,
            default => 30,
        };

        $records = $farm->growthRecords()
            ->where('measurement_date', '>=', now()->subDays($days))
            ->orderBy('measurement_date', 'asc')
            ->get();

        // Growth trend by week
        $growthTrend = [];
        $records->groupBy(function ($record) {
            return $record->measurement_date->format('Y-W');
        })->each(function ($group, $week) use (&$growthTrend) {
            $growthTrend[$week] = [
                'week' => $week,
                'average_weight' => $group->avg('current_weight'),
                'count' => $group->count(),
            ];
        });

        // Animal performance ranking
        $performance = $records->groupBy('animal_id')
            ->map(function ($group) {
                $weights = $group->pluck('current_weight')->toArray();
                $gains = $group->pluck('daily_gain')->filter()->toArray();
                return [
                    'animal_id' => $group->first()->animal->identifier,
                    'latest_weight' => end($weights),
                    'average_gain' => !empty($gains) ? array_sum($gains) / count($gains) : 0,
                    'measurements' => count($weights),
                ];
            })
            ->sortByDesc('average_gain')
            ->values()
            ->take(10)
            ->toArray();

        return response()->json([
            'period_days' => $days,
            'total_records' => $records->count(),
            'growth_trend' => array_values($growthTrend),
            'animal_performance' => $performance,
            'average_weight' => round($records->avg('current_weight'), 2),
            'weight_range' => [
                'min' => round($records->min('current_weight'), 2),
                'max' => round($records->max('current_weight'), 2),
            ],
        ]);
    }

    private function authorizeGrowthAccess(Request $request, Farm $farm, string $permission): void
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

        $aliases = [
            'viewGrowth' => ['viewReports', 'manageHerd', 'manageHealth', 'manageGrowth'],
            'manageGrowth' => ['manageHerd', 'manageHealth', 'manageGrowth'],
        ];

        $allowed = $permissions ?? [];
        $matches = $aliases[$permission] ?? [$permission];

        if (! array_intersect($matches, $allowed)) {
            abort(403, 'You do not have permission to access growth records.');
        }
    }

    private function defaultPermissions(string $role): array
    {
        return match ($role) {
            'farmManager' => ['manageHerd', 'manageFeed', 'manageHealth', 'viewReports'],
            'veterinarian' => ['viewHerd', 'manageHealth'],
            'farmWorker' => ['viewHerd', 'viewHealth'],
            default => [],
        };
    }
}
