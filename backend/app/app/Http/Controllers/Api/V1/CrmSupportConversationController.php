<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\FarmNotification;
use App\Models\SupportConversation;
use App\Models\SupportMessage;
use App\Models\User;
use App\Services\Crm\SupportConversationAssigner;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CrmSupportConversationController extends Controller
{
    public function index(Request $request, SupportConversationAssigner $assigner): JsonResponse
    {
        $this->authorizeCrm($request->user());
        $data = $request->validate([
            'farm_id' => ['required', 'integer'],
            'status' => ['sometimes', 'in:open,closed,all'],
        ]);
        $this->authorizeFarm($request, (int) $data['farm_id']);

        $conversations = SupportConversation::query()
            ->where('farm_id', $data['farm_id'])
            ->when(($data['status'] ?? 'open') !== 'all', fn ($query) => $query->where('status', $data['status'] ?? 'open'))
            ->with([
                'customer:id,name,email,phone,company,status',
                'appUser:id,name,email,role',
                'assignee:id,name,email,crm_role',
                'latestMessage.sender:id,name,crm_role,role',
            ])
            ->withCount(['messages as unread_count' => fn ($query) => $query->where('sender_role', 'app')->whereNull('read_at')])
            ->orderByDesc('last_message_at')
            ->paginate(min(max($request->integer('per_page', 30), 1), 100));

        foreach ($conversations->getCollection() as $conversation) {
            if ($conversation->status === 'open') {
                $assigner->assignIfAvailable($conversation);
                $conversation->load('assignee:id,name,email,crm_role');
            }
        }

        return response()->json([
            'data' => $conversations->getCollection()->map(fn (SupportConversation $conversation): array => $this->summaryData($conversation)),
            'meta' => [
                'current_page' => $conversations->currentPage(),
                'last_page' => $conversations->lastPage(),
                'per_page' => $conversations->perPage(),
                'total' => $conversations->total(),
            ],
        ]);
    }

    public function show(Request $request, SupportConversation $conversation): JsonResponse
    {
        $this->authorizeConversation($request, $conversation);
        $conversation->load([
            'customer:id,name,email,phone,company,status',
            'appUser:id,name,email,role',
            'assignee:id,name,email,crm_role',
            'messages.sender:id,name,crm_role,role',
        ]);
        $conversation->loadCount(['messages as unread_count' => fn ($query) => $query->where('sender_role', 'app')->whereNull('read_at')]);

        return response()->json(['data' => $this->detailData($conversation)]);
    }

    public function storeMessage(Request $request, SupportConversation $conversation): JsonResponse
    {
        $this->authorizeConversation($request, $conversation);
        $data = $request->validate(['message' => ['required', 'string', 'max:4000']]);

        $message = DB::transaction(function () use ($request, $conversation, $data): SupportMessage {
            $message = $conversation->messages()->create([
                'sender_id' => $request->user()->id,
                'sender_role' => 'crm',
                'body' => trim($data['message']),
            ]);
            $conversation->update(['status' => 'open', 'last_message_at' => now()]);
            FarmNotification::create([
                'farm_id' => $conversation->farm_id,
                'recipient_id' => $conversation->app_user_id,
                'type' => 'crm_message',
                'title' => 'Customer Care',
                'body' => Str::limit(trim($data['message']), 180),
                'severity' => 'info',
                'related_type' => 'support_conversation',
                'related_id' => $conversation->id,
                'action_route' => '/support',
            ]);

            return $message;
        });
        app(SupportConversationAssigner::class)->assignIfAvailable($conversation->fresh());

        return response()->json(['data' => $this->messageData($message->load('sender:id,name,crm_role,role'))], 201);
    }

    public function update(Request $request, SupportConversation $conversation): JsonResponse
    {
        $this->authorizeConversation($request, $conversation);
        $data = $request->validate([
            'assigned_user_id' => ['sometimes', 'nullable', 'integer', 'exists:users,id'],
            'status' => ['sometimes', 'in:open,closed'],
        ]);

        if (array_key_exists('assigned_user_id', $data) && $data['assigned_user_id'] !== null) {
            $assignee = User::query()
                ->whereKey($data['assigned_user_id'])
                ->whereNull('crm_closed_at')
                ->whereHas('farms', fn ($query) => $query->where('farms.id', $conversation->farm_id))
                ->first();
            $role = $assignee?->crm_role ?? ($assignee?->role === 'farmOwner' ? 'admin' : null);
            abort_unless(
                $assignee
                    && $assignee->crm_online_until?->isFuture()
                    && in_array($role, ['admin', 'customer_support'], true),
                422,
                'Assignee must be an online admin or customer support user in this farm.',
            );
        }

        $conversation->update($data);
        $conversation->load(['appUser:id,name,email,role', 'assignee:id,name,email,crm_role', 'latestMessage.sender:id,name,crm_role,role']);
        $conversation->loadCount(['messages as unread_count' => fn ($query) => $query->where('sender_role', 'app')->whereNull('read_at')]);

        return response()->json(['data' => $this->summaryData($conversation)]);
    }

    public function markAsRead(Request $request, SupportConversation $conversation): JsonResponse
    {
        $this->authorizeConversation($request, $conversation);
        $conversation->messages()
            ->where('sender_role', 'app')
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json(['data' => ['marked_read' => true]]);
    }

    private function authorizeConversation(Request $request, SupportConversation $conversation): void
    {
        $this->authorizeCrm($request->user());
        $this->authorizeFarm($request, $conversation->farm_id);
    }

    private function authorizeFarm(Request $request, int $farmId): void
    {
        abort_unless($request->user()->farms()->where('farms.id', $farmId)->exists(), 403, 'You do not have access to this farm.');
    }

    private function authorizeCrm(User $user): void
    {
        $role = $user->crm_role ?? ($user->role === 'farmOwner' ? 'admin' : null);
        abort_unless(in_array($role, ['admin', 'customer_support'], true), 403, 'Only admins and customer support can access support conversations.');
    }

    private function summaryData(SupportConversation $conversation): array
    {
        $customer = $conversation->customer ?? $conversation->appUser;

        return [
            'id' => (string) $conversation->id,
            'farm_id' => (string) $conversation->farm_id,
            'status' => $conversation->status,
            'customer' => $customer ? [
                'id' => (string) $customer->id,
                'name' => $customer->name,
                'email' => $customer->email,
                'phone' => $customer->phone ?? null,
                'company' => $customer->company ?? null,
                'role' => $customer->role ?? $customer->status ?? null,
            ] : null,
            'assigned_agent' => $conversation->assignee ? [
                'id' => (string) $conversation->assignee->id,
                'name' => $conversation->assignee->name,
                'email' => $conversation->assignee->email,
                'role' => $conversation->assignee->crm_role,
            ] : null,
            'unread_count' => (int) $conversation->unread_count,
            'last_message' => $conversation->latestMessage ? $this->messageData($conversation->latestMessage) : null,
            'last_message_at' => $conversation->last_message_at?->toIso8601String(),
        ];
    }

    private function detailData(SupportConversation $conversation): array
    {
        return [
            ...$this->summaryData($conversation),
            'messages' => $conversation->messages->map(fn (SupportMessage $message): array => $this->messageData($message))->values(),
        ];
    }

    private function messageData(SupportMessage $message): array
    {
        return [
            'id' => (string) $message->id,
            'sender_id' => $message->sender_id === null ? null : (string) $message->sender_id,
            'sender_role' => $message->sender_role,
            'sender_name' => $message->sender?->name ?? ($message->sender_role === 'crm' ? 'Customer Support' : 'Farm member'),
            'body' => $message->body,
            'read_at' => $message->read_at?->toIso8601String(),
            'created_at' => $message->created_at?->toIso8601String(),
        ];
    }
}