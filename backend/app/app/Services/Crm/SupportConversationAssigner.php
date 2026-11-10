<?php

namespace App\Services\Crm;

use App\Models\CrmTask;
use App\Models\FarmTask;
use App\Models\SupportConversation;
use App\Models\User;

class SupportConversationAssigner
{
    public function assignIfAvailable(SupportConversation $conversation): SupportConversation
    {
        $currentAssignee = $conversation->assigned_user_id === null
            ? null
            : User::query()->find($conversation->assigned_user_id);

        if ($currentAssignee !== null
            && $this->isOnlineForFarm($currentAssignee, $conversation->farm_id)
            && ! $this->hasOpenTasks($currentAssignee, $conversation->farm_id)) {
            return $conversation;
        }

        $agents = $this->availableAgents($conversation->farm_id);
        $agent = $currentAssignee === null
            ? $agents->first()
            : $agents->firstWhere('id', '!=', $currentAssignee->id);
        if ($agent === null
            && $currentAssignee !== null
            && $this->isOnlineForFarm($currentAssignee, $conversation->farm_id)) {
            return $conversation;
        }

        if ($agent !== null) {
            $conversation->forceFill(['assigned_user_id' => $agent->id])->save();
        }

        return $conversation;
    }

    private function hasOpenTasks(User $user, int $farmId): bool
    {
        return CrmTask::query()
                ->where('farm_id', $farmId)
                ->where('assigned_to', $user->id)
                ->where('status', 'open')
                ->exists()
            || FarmTask::query()
                ->where('farm_id', $farmId)
                ->where('assigned_to', $user->id)
                ->where('status', 'open')
                ->exists();
    }

    public function availableAgents(int $farmId)
    {
        $openChats = SupportConversation::query()
            ->selectRaw('COUNT(*)')
            ->whereColumn('support_conversations.assigned_user_id', 'users.id')
            ->where('support_conversations.farm_id', $farmId)
            ->where('support_conversations.status', 'open');
        $openCrmTasks = CrmTask::query()
            ->selectRaw('COUNT(*)')
            ->whereColumn('crm_tasks.assigned_to', 'users.id')
            ->where('crm_tasks.farm_id', $farmId)
            ->where('crm_tasks.status', 'open');
        $openFarmTasks = FarmTask::query()
            ->selectRaw('COUNT(*)')
            ->whereColumn('farm_tasks.assigned_to', 'users.id')
            ->where('farm_tasks.farm_id', $farmId)
            ->where('farm_tasks.status', 'open');

        return User::query()
            ->select('users.*')
            ->selectSub($openChats, 'open_chat_count')
            ->selectSub($openCrmTasks, 'open_crm_task_count')
            ->selectSub($openFarmTasks, 'open_farm_task_count')
            ->whereNull('users.crm_closed_at')
            ->whereNotNull('users.crm_online_until')
            ->where('users.crm_online_until', '>', now())
            ->where(function ($query): void {
                $query->whereIn('users.crm_role', ['admin', 'customer_support'])
                    ->orWhere(function ($query): void {
                        $query->whereNull('users.crm_role')
                            ->where('users.role', 'farmOwner');
                    });
            })
            ->whereHas('farms', fn ($query) => $query->where('farms.id', $farmId))
            ->orderByRaw('(open_chat_count + open_crm_task_count + open_farm_task_count)')
            ->orderBy('users.id')
            ->get();
    }

    private function isOnlineForFarm(User $user, int $farmId): bool
    {
        return $user->crm_closed_at === null
            && $user->crm_online_until !== null
            && $user->crm_online_until->isFuture()
            && $user->farms()->where('farms.id', $farmId)->exists()
            && (in_array($user->crm_role, ['admin', 'customer_support'], true)
                || ($user->crm_role === null && $user->role === 'farmOwner'));
    }
}
