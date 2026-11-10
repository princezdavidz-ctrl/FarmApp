<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\FarmResource;
use App\Models\Farm;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FarmOverviewController extends Controller
{
    public function show(Request $request, Farm $farm): JsonResponse
    {
        if (! $request->user()->farms()->where('farms.id', $farm->id)->exists()) {
            abort(403, 'You do not have access to this farm.');
        }

        return response()->json([
            'farm' => new FarmResource($farm),
            'herd_count' => $farm->animals()->where('status', 'active')->count(),
            'feed_stock' => round((float) $farm->feedStocks()->sum('quantity'), 2),
            'feed_unit' => 'bags',
            'tasks_due' => null,
            'sales_this_week' => null,
            'recent_activity' => [],
        ]);
    }
}
