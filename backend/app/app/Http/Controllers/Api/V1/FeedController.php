<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Feed\StoreFeedStockRequest;
use App\Http\Requests\Feed\StoreFeedUsageRequest;
use App\Http\Resources\Feed\FeedStockResource;
use App\Http\Resources\Feed\FeedUsageResource;
use App\Models\Farm;
use App\Models\FeedReminder;
use App\Models\FeedStock;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FeedController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeFeedAccess($request, $farm);
        $pricedUsage = DB::table('feed_usages')
            ->join('feed_stocks', 'feed_stocks.id', '=', 'feed_usages.feed_stock_id')
            ->where('feed_usages.farm_id', $farm->id)
            ->whereBetween('feed_usages.used_at', [now()->startOfMonth(), now()])
            ->whereNotNull('feed_stocks.unit_cost')
            ->selectRaw('COALESCE(SUM(feed_usages.quantity * feed_stocks.unit_cost), 0) AS total, COUNT(*) AS records')
            ->first();

        return response()->json([
            'stock' => FeedStockResource::collection($farm->feedStocks()->latest()->get()),
            'usage' => FeedUsageResource::collection($farm->feedUsages()->with('stock')->latest('used_at')->limit(30)->get()),
            'monthly_feed_cost' => (float) ($pricedUsage->total ?? 0),
            'has_monthly_feed_cost' => (int) ($pricedUsage->records ?? 0) > 0,
        ]);
    }

    public function storeStock(StoreFeedStockRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeFeedAccess($request, $farm);
        $stock = $farm->feedStocks()->create($request->validated() + ['created_by' => $request->user()->id]);

        return response()->json(['data' => new FeedStockResource($stock)], 201);
    }

    public function storeUsage(StoreFeedUsageRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeFeedAccess($request, $farm);
        $data = $request->validated();
        if (! empty($data['feed_stock_id'])) {
            $stock = $farm->feedStocks()->findOrFail($data['feed_stock_id']);
            if ($stock->unit !== $data['unit']) {
                return response()->json(['message' => 'Usage unit must match the selected feed stock unit.'], 422);
            }
            if ((float) $stock->quantity < (float) $data['quantity']) {
                return response()->json(['message' => 'Usage exceeds available stock.'], 422);
            }
        }
        $usage = DB::transaction(function () use ($farm, $request, $data) {
            $usage = $farm->feedUsages()->create($data + ['created_by' => $request->user()->id]);
            if (! empty($data['feed_stock_id'])) {
                FeedStock::whereKey($data['feed_stock_id'])->decrement('quantity', $data['quantity']);
            }

            return $usage->load('stock');
        });

        return response()->json(['data' => new FeedUsageResource($usage)], 201);
    }

    public function syncReminders(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeFeedAccess($request, $farm);
        $data = $request->validate([
            'enabled' => ['required', 'boolean'],
            'timezone' => ['required', 'string', 'timezone'],
            'entries' => ['present', 'array', 'max:20'],
            'entries.*.id' => ['required', 'string', 'max:100', 'distinct:strict'],
            'entries.*.name' => ['required', 'string', 'max:120'],
            'entries.*.minutes_after_midnight' => ['required', 'integer', 'between:0,1439'],
            'entries.*.reminders_enabled' => ['required', 'boolean'],
        ]);

        $activeEntries = collect($data['entries'])
            ->filter(fn (array $entry): bool => $data['enabled'] && $entry['reminders_enabled'])
            ->values();
        DB::transaction(function () use ($request, $farm, $data, $activeEntries): void {
            $query = FeedReminder::query()
                ->where('farm_id', $farm->id)
                ->where('user_id', $request->user()->id);
            $activeIds = $activeEntries->pluck('id')->all();
            if ($activeIds === []) {
                $query->delete();

                return;
            }

            (clone $query)->whereNotIn('schedule_id', $activeIds)->delete();
            foreach ($activeEntries as $entry) {
                FeedReminder::query()->updateOrCreate(
                    [
                        'farm_id' => $farm->id,
                        'user_id' => $request->user()->id,
                        'schedule_id' => $entry['id'],
                    ],
                    [
                        'name' => $entry['name'],
                        'minutes_after_midnight' => $entry['minutes_after_midnight'],
                        'timezone' => $data['timezone'],
                        'enabled' => true,
                    ],
                );
            }
        });

        return response()->json(['message' => 'Feeding reminders synchronized.']);
    }

    private function authorizeFeedAccess(Request $request, Farm $farm): void
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
            ? match ($user->role) {
                'farmManager' => ['manageFeed'],
                'farmWorker' => ['manageFeed'],
                default => [],
            }
        : json_decode($membership->pivot->permissions, true);
        if (! in_array('manageFeed', $permissions ?? [], true)) {
            abort(403, 'You do not have permission to manage feed.');
        }
    }
}
