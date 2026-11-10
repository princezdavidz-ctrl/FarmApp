<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Feed\StoreFeedStockRequest;
use App\Http\Requests\Feed\StoreFeedUsageRequest;
use App\Http\Resources\Feed\FeedStockResource;
use App\Http\Resources\Feed\FeedUsageResource;
use App\Models\Farm;
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

    private function authorizeFeedAccess(Request $request, Farm $farm): void
    {
        $user = $request->user();
        $membership = $user->farms()->where('farms.id', $farm->id)->first();
        if ($membership === null) abort(403, 'You do not have access to this farm.');
        if ($user->role === 'farmOwner') return;
        $permissions = $membership->pivot->permissions === null
            ? match ($user->role) {
                'farmManager' => ['manageFeed'],
                'farmWorker' => ['manageFeed'],
                default => [],
            }
            : json_decode($membership->pivot->permissions, true);
        if (! in_array('manageFeed', $permissions ?? [], true)) abort(403, 'You do not have permission to manage feed.');
    }
}
