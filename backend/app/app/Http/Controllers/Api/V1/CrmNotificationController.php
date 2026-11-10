<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\FarmNotification;
use App\Models\SupportConversation;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CrmNotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $this->crmStaff($user);
        $farmId = $request->integer('farm_id');
        if (! $user->is_global_crm_admin && ! $user->farms()->where('farms.id', $farmId)->exists()) abort(403, 'You do not have access to this farm.');
        $items = \DB::table('crm_notifications')
            ->leftJoin('users as senders', 'senders.id', '=', 'crm_notifications.sender_id')
            ->leftJoin('users as recipients', 'recipients.id', '=', 'crm_notifications.recipient_id')
            ->select('crm_notifications.*', 'senders.name as sender_name', 'senders.email as sender_email', 'recipients.name as recipient_name')
            ->where('crm_notifications.farm_id', $farmId)
            ->where(fn ($query) => $query->whereNull('crm_notifications.recipient_id')->orWhere('crm_notifications.recipient_id', $user->id))
            ->latest('crm_notifications.created_at')->limit(50)->get();
        return response()->json(['data' => $items]);
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();
        $role = $user->crm_role ?? ($user->role === 'farmOwner' ? 'admin' : null);
        if (! $user->is_global_crm_admin && ! in_array($role, ['admin', 'customer_support'], true)) {
            abort(403, 'Only admins and customer support can send notifications.');
        }
        $data = $request->validate([
            'farm_id' => ['required', 'integer', 'exists:farms,id'],
            'message' => ['required', 'string', 'max:1000'],
            'recipient_id' => ['nullable', 'integer', 'exists:users,id'],
            'audience_scope' => ['sometimes', 'in:farm,all_registered'],
            'title' => ['sometimes', 'string', 'max:160'],
            'kind' => ['sometimes', 'in:reply,broadcast'],
        ]);
        if (! $user->is_global_crm_admin && ! $user->farms()->where('farms.id', $data['farm_id'])->exists()) {
            abort(403, 'You do not have access to this farm.');
        }
        if (! empty($data['recipient_id'])) {
            $recipient = User::query()
                ->whereKey($data['recipient_id'])
                ->whereHas('farms', fn ($query) => $query->where('farms.id', $data['farm_id']))
                ->where(fn ($query) => $query->where('role', 'farmOwner')
                    ->orWhere(fn ($query) => $query->whereIn('role', ['farmManager', 'farmWorker'])->whereNull('crm_role')))
                ->exists();
            abort_unless($recipient, 422, 'Recipient must be an app member of this farm.');
        }

        $kind = $data['kind'] ?? (isset($data['recipient_id']) ? 'reply' : 'broadcast');
        $audienceScope = $data['audience_scope'] ?? 'farm';
        if ($audienceScope === 'all_registered') {
            abort_unless($user->is_global_crm_admin, 403, 'Only the central CRM administrator can message all registered app users.');
            abort_unless($kind === 'broadcast' && ! isset($data['recipient_id']), 422, 'A global broadcast cannot target an individual recipient.');
        }
        if ($kind === 'reply' && ! isset($data['recipient_id'])) {
            abort(422, 'A support reply must target one app member.');
        }

        $result = DB::transaction(function () use ($data, $user, $kind, $audienceScope): array {
            $messageId = DB::table('crm_notifications')->insertGetId([
                'farm_id' => $data['farm_id'],
                'sender_id' => $user->id,
                'recipient_id' => $data['recipient_id'] ?? null,
                'message' => trim($data['message']),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $recipients = isset($data['recipient_id'])
                ? User::query()->whereKey($data['recipient_id'])->get()
                : ($audienceScope === 'all_registered'
                    ? User::query()
                    ->whereKeyNot($user->id)
                    ->whereNull('crm_closed_at')
                    ->where(function ($query) {
                        $query->where('role', 'farmOwner')
                            ->orWhere(fn ($appUsers) => $appUsers->whereIn('role', ['farmManager', 'farmWorker'])->whereNull('crm_role'));
                    })
                    ->whereHas('farms')
                    ->with(['farms' => fn ($query) => $query->orderBy('farms.id')])
                    ->get()
                    : User::query()
                    ->whereHas('farms', fn ($query) => $query->where('farms.id', $data['farm_id']))
                    ->whereKeyNot($user->id)
                    ->whereNull('crm_closed_at')
                    ->where(fn ($query) => $query->where('role', 'farmOwner')
                        ->orWhere(fn ($query) => $query->whereIn('role', ['farmManager', 'farmWorker'])->whereNull('crm_role')))
                    ->get());
            $title = trim($data['title'] ?? ($kind === 'reply' ? 'Message from '.$user->name : 'Announcement from '.$user->name));
            $broadcastId = DB::table('communication_broadcasts')->insertGetId([
                'farm_id' => $data['farm_id'],
                'sender_id' => $user->id,
                'recipient_id' => $data['recipient_id'] ?? null,
                'audience' => isset($data['recipient_id']) ? 'individual' : ($audienceScope === 'all_registered' ? 'all_registered' : 'farm'),
                'title' => $title,
                'message' => trim($data['message']),
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            foreach ($recipients as $recipient) {
                $recipientFarmId = $audienceScope === 'all_registered'
                    ? $recipient->farms->first()->id
                    : $data['farm_id'];
                $notification = FarmNotification::create([
                    'farm_id' => $recipientFarmId,
                    'recipient_id' => $recipient->id,
                    'type' => $kind === 'reply' ? 'crm_message' : 'crm_broadcast',
                    'title' => $title,
                    'body' => trim($data['message']),
                    'severity' => 'info',
                    'related_type' => $audienceScope === 'all_registered'
                        ? 'global_crm_broadcast'
                        : ($kind === 'reply' ? 'support_conversation' : 'communication_broadcast'),
                    'related_id' => $broadcastId,
                    'action_route' => $kind === 'reply' ? '/support' : '/notifications',
                ]);

                if ($kind === 'reply' && isset($data['recipient_id'])) {
                    $conversation = SupportConversation::query()
                        ->where('farm_id', $data['farm_id'])
                        ->where('app_user_id', $recipient->id)
                        ->first();
                    if ($conversation !== null) {
                        $conversation->messages()->create([
                            'sender_id' => $user->id,
                            'sender_role' => 'crm',
                            'body' => trim($data['message']),
                        ]);
                        $conversation->update(['status' => 'open', 'last_message_at' => now()]);
                    }
                }

                DB::table('communication_broadcast_recipients')->insert([
                    'broadcast_id' => $broadcastId,
                    'recipient_id' => $recipient->id,
                    'farm_notification_id' => $notification->id,
                    'push_status' => 'pending',
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            return [
                'message' => DB::table('crm_notifications')->find($messageId),
                'broadcast_id' => (string) $broadcastId,
                'recipient_count' => $recipients->count(),
            ];
        });

        return response()->json([
            'data' => [
                ...(array) $result['message'],
                'audience' => isset($data['recipient_id'])
                    ? 'individual'
                    : ($audienceScope === 'all_registered' ? 'all_registered' : 'farm'),
                'audience_scope' => $audienceScope,
                'broadcast_id' => $result['broadcast_id'],
                'recipient_count' => $result['recipient_count'],
            ],
        ], 201);
    }

    public function broadcasts(Request $request): JsonResponse
    {
        $user = $request->user();
        $this->crmStaff($user);
        $data = $request->validate(['farm_id' => ['required', 'integer']]);
        abort_unless($user->is_global_crm_admin || $user->farms()->where('farms.id', $data['farm_id'])->exists(), 403, 'You do not have access to this farm.');

        $items = DB::table('communication_broadcasts')
            ->join('users as senders', 'senders.id', '=', 'communication_broadcasts.sender_id')
            ->leftJoin('users as recipients', 'recipients.id', '=', 'communication_broadcasts.recipient_id')
            ->leftJoin('communication_broadcast_recipients as delivery', 'delivery.broadcast_id', '=', 'communication_broadcasts.id')
            ->where('communication_broadcasts.farm_id', $data['farm_id'])
            ->groupBy(
                'communication_broadcasts.id',
                'communication_broadcasts.audience',
                'communication_broadcasts.title',
                'communication_broadcasts.message',
                'communication_broadcasts.created_at',
                'senders.name',
                'recipients.name',
            )
            ->orderByDesc('communication_broadcasts.created_at')
            ->limit(100)
            ->get([
                'communication_broadcasts.id',
                'communication_broadcasts.audience',
                'communication_broadcasts.title',
                'communication_broadcasts.message',
                'communication_broadcasts.created_at',
                'senders.name as sender_name',
                'recipients.name as recipient_name',
                DB::raw('COUNT(delivery.id) as recipient_count'),
                DB::raw("SUM(CASE WHEN delivery.push_status = 'sent' THEN 1 ELSE 0 END) as push_sent_count"),
            ]);

        return response()->json(['data' => $items]);
    }

    private function crmStaff(User $user): void
    {
        $role = $user->crm_role ?? ($user->role === 'farmOwner' ? 'admin' : null);
        if (! $user->is_global_crm_admin && ! in_array($role, ['admin', 'finance', 'customer_support'], true)) {
            abort(403, 'Only CRM staff can access notifications.');
        }
    }
}
