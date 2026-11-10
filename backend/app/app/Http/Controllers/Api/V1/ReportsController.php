<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\Breeding\PregnancyResource;
use App\Http\Resources\Growth\GrowthRecordResource;
use App\Http\Resources\Health\HealthRecordResource;
use App\Http\Resources\Herd\AnimalResource;
use App\Models\Animal;
use App\Models\FeedUsage;
use App\Models\GrowthRecord;
use App\Models\HealthRecord;
use App\Models\Payment;
use App\Models\Pregnancy;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class ReportsController extends Controller
{
    public function metrics(Request $request, int $farm): JsonResponse
    {
        $this->authorizeFarm($request, $farm);
        [$start, $end] = $this->period($request);

        $animals = Animal::query()->where('farm_id', $farm);
        $totalAnimals = (clone $animals)->count();
        $deceasedAnimals = (clone $animals)->where('status', 'deceased')->count();
        $growth = GrowthRecord::query()
            ->where('farm_id', $farm)
            ->whereBetween('measurement_date', [$start, $end]);
        $health = HealthRecord::query()
            ->where('farm_id', $farm)
            ->whereBetween('visit_date', [$start, $end]);

        return response()->json([
            'totalRevenue' => (float) Payment::query()
                ->where('farm_id', $farm)
                ->where('status', 'paid')
                ->whereBetween('paid_at', [$start, $end])
                ->sum('amount'),
            'totalExpenses' => 0.0,
            'mortalityRate' => $totalAnimals > 0 ? round(($deceasedAnimals / $totalAnimals) * 100, 2) : 0.0,
            'averageGrowth' => round((float) $growth->avg('weight_gain'), 2),
            'feedConsumption' => round((float) FeedUsage::query()
                ->where('farm_id', $farm)
                ->whereBetween('used_at', [$start, $end])
                ->sum('quantity'), 2),
            'salesCount' => (clone $animals)->where('status', 'sold')->whereBetween('updated_at', [$start, $end])->count(),
            'vaccinationCompletion' => $this->vaccinationCompletion($health),
            'startDate' => $start->toIso8601String(),
            'endDate' => $end->toIso8601String(),
        ]);
    }

    public function animalReport(Request $request, int $farm, Animal $animal): JsonResponse
    {
        $this->authorizeReportAccess($request, $farm);
        abort_if($animal->farm_id !== $farm, 404);

        $request->validate([
            'dateRange' => ['sometimes', 'string', 'in:today,week,month,year'],
            'startDate' => ['sometimes', 'date'],
            'endDate' => ['sometimes', 'date', 'after_or_equal:startDate'],
        ]);
        [$start, $end] = $this->period($request);

        $healthRecords = HealthRecord::query()
            ->where('farm_id', $farm)
            ->where('animal_id', $animal->id)
            ->whereBetween('visit_date', [$start, $end])
            ->latest('visit_date')
            ->get();
        $growthRecords = GrowthRecord::query()
            ->where('farm_id', $farm)
            ->where('animal_id', $animal->id)
            ->whereBetween('measurement_date', [$start, $end])
            ->latest('measurement_date')
            ->get();
        $pregnancies = Pregnancy::query()
            ->where('farm_id', $farm)
            ->where(function ($query) use ($animal) {
                $query->where('sow_id', $animal->id)
                    ->orWhere('boar_id', $animal->id);
            })
            ->where(function ($query) use ($start, $end) {
                $query->whereBetween('mating_date', [$start->toDateString(), $end->toDateString()])
                    ->orWhereBetween('expected_farrowing_date', [$start->toDateString(), $end->toDateString()])
                    ->orWhereBetween('actual_farrowing_date', [$start->toDateString(), $end->toDateString()]);
            })
            ->with(['sow', 'boar'])
            ->latest('mating_date')
            ->get();

        return response()->json([
            'data' => [
                'animal' => (new AnimalResource($animal))->toArray($request),
                'period' => [
                    'startDate' => $start->toIso8601String(),
                    'endDate' => $end->toIso8601String(),
                ],
                'healthRecords' => HealthRecordResource::collection($healthRecords)->resolve($request),
                'growthRecords' => GrowthRecordResource::collection($growthRecords)->resolve($request),
                'pregnancies' => PregnancyResource::collection($pregnancies)->resolve($request),
            ],
        ]);
    }

    private function authorizeFarm(Request $request, int $farm): void
    {
        if (! $request->user()->farms()->whereKey($farm)->exists()) {
            abort(403, 'You do not have access to this farm.');
        }
    }

    private function authorizeReportAccess(Request $request, int $farm): void
    {
        $user = $request->user();
        $membership = $user->farms()->where('farms.id', $farm)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');

        if ($user->role === 'farmOwner') {
            return;
        }

        $permissions = $membership->pivot->permissions === null
            ? match ($user->role) {
                'farmManager' => ['viewReports'],
                default => [],
            }
            : json_decode($membership->pivot->permissions, true);

        abort_unless(in_array('viewReports', $permissions ?? [], true), 403,
            'You do not have permission to view reports.');
    }

    /** @return array{0: Carbon, 1: Carbon} */
    private function period(Request $request): array
    {
        $now = now();
        $range = $request->string('dateRange', 'month')->lower()->value();
        $start = match ($range) {
            'today' => $now->copy()->startOfDay(),
            'week' => $now->copy()->startOfWeek(),
            'year' => $now->copy()->startOfYear(),
            default => $now->copy()->startOfMonth(),
        };
        $end = $now->copy()->endOfDay();

        if ($request->filled('startDate')) {
            $start = Carbon::parse($request->string('startDate')->value())->startOfDay();
        }
        if ($request->filled('endDate')) {
            $end = Carbon::parse($request->string('endDate')->value())->endOfDay();
        }

        return [$start, $end];
    }

    private function vaccinationCompletion($health): float
    {
        $vaccinations = (clone $health)->where('type', 'vaccination')->count();
        if ($vaccinations === 0) {
            return 0.0;
        }

        $completed = (clone $health)->where('type', 'vaccination')->where('status', 'completed')->count();
        return round(($completed / $vaccinations) * 100, 2);
    }
}