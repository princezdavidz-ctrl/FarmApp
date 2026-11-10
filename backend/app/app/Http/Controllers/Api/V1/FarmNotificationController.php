<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\StoreFarmMessageRequest;
use App\Http\Resources\FarmNotificationResource;
use App\Models\Farm;
use App\Models\FarmNotification;
use App\Models\SupportConversation;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FarmNotificationController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeMember($request, $farm);

        $notifications = FarmNotification::query()
            ->where(function ($query) use ($farm, $request) {
                $query->where('farm_id', $farm->id)
                    ->orWhere(fn ($global) => $global
                        ->where('related_type', 'global_crm_broadcast')
                        ->where('recipient_id', $request->user()->id));
            })
            ->where(function ($query) use ($request) {
                $query->whereNull('recipient_id')->orWhere('recipient_id', $request->user()->id);
            })
            ->latest()
            ->paginate(30);

        return FarmNotificationResource::collection($notifications)->response();
    }

    public function markAsRead(Request $request, Farm $farm, FarmNotification $notification): JsonResponse
    {
        $this->authorizeMember($request, $farm);
        $this->authorizeNotification($request, $farm, $notification);

        if ($notification->read_at === null) {
            $notification->forceFill(['read_at' => now()])->save();
        }

        return response()->json(['data' => new FarmNotificationResource($notification)]);
    }

    public function sendMessage(StoreFarmMessageRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeMember($request, $farm);
        abort_unless(
            in_array($request->user()->role, ['farmOwner', 'farmManager', 'farmWorker'], true)
                && ($request->user()->crm_role === null || $request->user()->role === 'farmOwner'),
            403,
            'Only farm app members can message customer support.',
        );

        $message = trim($request->string('message')->toString());
        $notification = DB::transaction(function () use ($farm, $request, $message): FarmNotification {
            $conversation = SupportConversation::query()
                ->where('farm_id', $farm->id)
                ->where('app_user_id', $request->user()->id)
                ->lockForUpdate()
                ->first();

            if ($conversation === null) {
                $conversation = SupportConversation::create([
                    'farm_id' => $farm->id,
                    'app_user_id' => $request->user()->id,
                    'status' => 'open',
                ]);
            }
            $conversation->messages()->create([
                'sender_id' => $request->user()->id,
                'sender_role' => 'app',
                'body' => $message,
            ]);
            $conversation->update(['status' => 'open', 'last_message_at' => now()]);

            $legacyMessageId = DB::table('crm_notifications')->insertGetId([
                'farm_id' => $farm->id,
                'sender_id' => $request->user()->id,
                'recipient_id' => null,
                'message' => $message,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            return FarmNotification::create([
                'farm_id' => $farm->id,
                'recipient_id' => $request->user()->id,
                'type' => 'crm_message_sent',
                'title' => 'Message sent to Farm App CRM',
                'body' => $message,
                'severity' => 'success',
                'related_type' => 'crm_notification',
                'related_id' => $legacyMessageId,
                'action_route' => '/notifications',
            ]);
        });

        return response()->json(['data' => new FarmNotificationResource($notification)], 201);
    }

    private function authorizeMember(Request $request, Farm $farm): void
    {
        $belongs = $request->user()->farms()->where('farms.id', $farm->id)->exists();

        if (! $belongs) {
            abort(403, 'You do not have access to this farm.');
        }
    }

    private function authorizeNotification(Request $request, Farm $farm, FarmNotification $notification): void
    {
        $isAccessible = ($notification->farm_id === $farm->id
                || ($notification->related_type === 'global_crm_broadcast'
                    && $notification->recipient_id === $request->user()->id))
            && ($notification->recipient_id === null || $notification->recipient_id === $request->user()->id);

        if (! $isAccessible) {
            abort(404, 'Notification not found.');
        }
    }
}