<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\BuyerNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BuyerNotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        abort_unless($request->user()->role === 'buyer', 403, 'Only buyer accounts can view buyer notifications.');

        $query = BuyerNotification::query()
            ->where('buyer_user_id', $request->user()->id);

        return response()->json([
            'data' => (clone $query)->latest()->limit(100)->get()->map(fn (BuyerNotification $notification): array => [
                'id' => (string) $notification->id,
                'type' => $notification->type,
                'title' => $notification->title,
                'body' => $notification->body,
                'action_route' => $notification->action_route,
                'read_at' => $notification->read_at?->toIso8601String(),
                'created_at' => $notification->created_at?->toIso8601String(),
            ]),
            'unread_count' => (clone $query)->whereNull('read_at')->count(),
        ]);
    }

    public function markAsRead(Request $request, BuyerNotification $notification): JsonResponse
    {
        abort_unless($request->user()->role === 'buyer', 403, 'Only buyer accounts can update buyer notifications.');
        abort_unless((int) $notification->buyer_user_id === (int) $request->user()->id, 404);

        $notification->update(['read_at' => $notification->read_at ?? now()]);

        return response()->json([
            'data' => [
                'id' => (string) $notification->id,
                'read_at' => $notification->read_at?->toIso8601String(),
            ],
        ]);
    }
}
