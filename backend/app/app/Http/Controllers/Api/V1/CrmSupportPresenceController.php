<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Crm\SupportConversationAssigner;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CrmSupportPresenceController extends Controller
{
    public function show(Request $request, SupportConversationAssigner $assigner): JsonResponse
    {
        $user = $request->user();
        $this->authorizeCrm($user);
        $data = $request->validate(['farm_id' => ['required', 'integer', 'exists:farms,id']]);
        $farmId = (int) $data['farm_id'];
        $this->authorizeFarm($user, $farmId);

        return response()->json([
            'data' => [
                'online_agents' => $assigner->availableAgents($farmId)
                    ->map(fn (User $agent): array => $this->agentData($agent))
                    ->values(),
                'current_user_online' => $user->crm_online_until?->isFuture() ?? false,
            ],
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $user = $request->user();
        $this->authorizeCrm($user);
        $data = $request->validate([
            'online' => ['required', 'boolean'],
            'farm_id' => ['required', 'integer', 'exists:farms,id'],
        ]);
        $this->authorizeFarm($user, (int) $data['farm_id']);

        $user->forceFill([
            'crm_online_until' => $data['online'] ? now()->addSeconds(90) : null,
        ])->save();

        return response()->json([
            'data' => [
                'online' => $user->crm_online_until?->isFuture() ?? false,
                'online_until' => $user->crm_online_until?->toIso8601String(),
            ],
        ]);
    }

    private function authorizeCrm(User $user): void
    {
        $role = $user->crm_role ?? ($user->role === 'farmOwner' ? 'admin' : null);
        abort_unless(in_array($role, ['admin', 'customer_support'], true), 403, 'Only admins and customer support can set support availability.');
        abort_if($user->crm_closed_at !== null, 403, 'Suspended CRM users cannot accept support conversations.');
    }

    private function authorizeFarm(User $user, int $farmId): void
    {
        abort_unless($user->farms()->where('farms.id', $farmId)->exists(), 403, 'You do not have access to this farm.');
    }

    private function agentData(User $agent): array
    {
        return [
            'id' => (string) $agent->id,
            'name' => $agent->name,
            'role' => $agent->crm_role ?? 'admin',
            'online_until' => $agent->crm_online_until?->toIso8601String(),
            'open_chats' => (int) $agent->open_chat_count,
            'open_crm_tasks' => (int) $agent->open_crm_task_count,
            'open_farm_tasks' => (int) $agent->open_farm_task_count,
        ];
    }
}
