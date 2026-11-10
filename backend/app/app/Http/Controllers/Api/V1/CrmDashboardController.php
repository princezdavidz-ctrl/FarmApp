<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CrmCustomerEvent;
use App\Models\CrmTask;
use App\Models\Customer;
use App\Models\CustomerInteraction;
use App\Models\CustomerOrder;
use App\Models\Farm;
use App\Models\Payment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class CrmDashboardController extends Controller
{
    public function overview(Request $request): JsonResponse
    {
        $this->authorizeCrmAccess($request);
        $farmId = $request->validate([
            'farm_id' => ['required', 'integer', 'exists:farms,id'],
        ])['farm_id'];

        if (! $request->user()->farms()->whereKey($farmId)->exists()) {
            abort(403, 'You do not have access to this farm.');
        }

        $now = now();
        $todayStart = $now->copy()->startOfDay();
        $tomorrowStart = $todayStart->copy()->addDay();
        $customers = Customer::query()->where('farm_id', $farmId);
        $totalCustomers = (clone $customers)->count();
        $statusCounts = (clone $customers)
            ->selectRaw('status, count(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');
        $growthStart = $now->copy()->startOfMonth()->subMonths(5);
        $growthMonthExpression = DB::connection()->getDriverName() === 'sqlite'
            ? "strftime('%Y-%m', created_at)"
            : "DATE_FORMAT(created_at, '%Y-%m')";
        $customerGrowth = (clone $customers)
            ->where('created_at', '>=', $growthStart)
            ->selectRaw("{$growthMonthExpression} as month, count(*) as total")
            ->groupBy('month')
            ->orderBy('month')
            ->pluck('total', 'month');
        $revenueCollected = Payment::query()
            ->where('farm_id', $farmId)
            ->where('status', 'paid')
            ->sum('amount');
        $pendingPayments = Payment::query()
            ->where('farm_id', $farmId)
            ->whereIn('status', ['pending', 'initiated'])
            ->count();
        $newOrders = CustomerOrder::query()
            ->where('farm_id', $farmId)
            ->where('status', 'pending')
            ->count();
        $openTasks = CrmTask::query()
            ->where('farm_id', $farmId)
            ->where('status', 'open');

        $tasks = (clone $openTasks)
            ->with(['customer:id,name', 'assignee:id,name'])
            ->orderByRaw('due_at IS NULL')
            ->orderBy('due_at')
            ->limit(10)
            ->get()
            ->map(fn (CrmTask $task): array => [
                'id' => (string) $task->id,
                'customer_id' => (string) $task->customer_id,
                'customer_name' => $task->customer?->name,
                'title' => $task->title,
                'priority' => $task->priority,
                'due_at' => $task->due_at?->toIso8601String(),
                'assigned_to' => $task->assigned_to !== null ? (string) $task->assigned_to : null,
                'assignee_name' => $task->assignee?->name,
            ]);

        $interactions = CustomerInteraction::query()
            ->whereHas('customer', fn ($query) => $query->where('farm_id', $farmId))
            ->with(['customer:id,name', 'user:id,name'])
            ->latest('occurred_at')
            ->limit(10)
            ->get()
            ->map(fn (CustomerInteraction $interaction): array => [
                'id' => 'interaction-'.$interaction->id,
                'customer_id' => (string) $interaction->customer_id,
                'customer_name' => $interaction->customer?->name,
                'type' => 'interaction',
                'subtype' => $interaction->type,
                'notes' => $interaction->notes,
                'actor_name' => $interaction->user?->name,
                'occurred_at' => $interaction->occurred_at?->toIso8601String(),
            ]);
        $events = CrmCustomerEvent::query()
            ->whereHas('customer', fn ($query) => $query->where('farm_id', $farmId))
            ->with(['customer:id,name', 'user:id,name'])
            ->latest('occurred_at')
            ->limit(10)
            ->get()
            ->map(fn (CrmCustomerEvent $event): array => [
                'id' => 'event-'.$event->id,
                'customer_id' => (string) $event->customer_id,
                'customer_name' => $event->customer?->name,
                'type' => $event->type,
                'subtype' => null,
                'notes' => null,
                'actor_name' => $event->user?->name,
                'occurred_at' => $event->occurred_at?->toIso8601String(),
            ]);

        $farm = Farm::query()->with(['users' => fn ($query) => $query->select('users.id', 'users.name', 'users.role', 'users.crm_role')])->findOrFail($farmId);
        $farmOwnerCount = $farm->users()->where('users.role', 'farmOwner')->count();
        $latestFarmPayment = $farm->payments()->latest('created_at')->first();
        $paidFarmOwnerCount = $farmOwnerCount > 0 && $latestFarmPayment?->status === 'paid' ? $farmOwnerCount : 0;
        $staff = $farm->users
            ->filter(fn ($member) => in_array($member->crm_role ?? ($member->role === 'farmOwner' ? 'admin' : null), ['admin', 'finance', 'customer_support'], true))
            ->map(function ($member) use ($farmId): array {
                $openTasks = CrmTask::query()->where('farm_id', $farmId)->where('status', 'open')->where('assigned_to', $member->id)->count();
                return ['id' => (string) $member->id, 'name' => $member->name, 'open_tasks' => $openTasks];
            })->values();

        $messages = \DB::table('crm_notifications')
            ->leftJoin('users as senders', 'senders.id', '=', 'crm_notifications.sender_id')
            ->select('crm_notifications.id', 'crm_notifications.message', 'crm_notifications.created_at', 'senders.name as sender_name')
            ->where('crm_notifications.farm_id', $farmId)
            ->latest('crm_notifications.created_at')
            ->limit(10)
            ->get()
            ->map(fn ($message): array => [
                'id' => (string) $message->id,
                'message' => $message->message,
                'sender_name' => $message->sender_name,
                'created_at' => Carbon::parse($message->created_at)->toIso8601String(),
            ]);

        return response()->json(['data' => [
            'generated_at' => $now->toIso8601String(),
            'customers' => [
                'total' => $totalCustomers + $farmOwnerCount,
                'active' => $totalCustomers - (int) ($statusCounts['lost'] ?? 0) + $paidFarmOwnerCount,
                'qualified' => (int) ($statusCounts['qualified'] ?? 0),
                'won' => (int) ($statusCounts['won'] ?? 0),
                'farm_owners' => $farmOwnerCount,
                'conversion_rate' => ($totalCustomers + $farmOwnerCount) > 0 ? round(((int) ($statusCounts['won'] ?? 0) / ($totalCustomers + $farmOwnerCount)) * 100, 2) : 0,
                'by_status' => $statusCounts,
                'growth' => collect(range(0, 5))->map(function (int $offset) use ($growthStart, $customerGrowth): array {
                    $month = $growthStart->copy()->addMonths($offset);
                    $key = $month->format('Y-m');
                    return ['label' => $month->format('M'), 'value' => (int) ($customerGrowth[$key] ?? 0)];
                })->values(),
            ],
            'tasks' => [
                'overdue' => (clone $openTasks)->whereNotNull('due_at')->where('due_at', '<', $now)->count(),
                'due_today' => (clone $openTasks)->whereBetween('due_at', [$todayStart, $tomorrowStart])->count(),
                'upcoming' => (clone $openTasks)->where('due_at', '>=', $tomorrowStart)->count(),
                'unassigned' => (clone $openTasks)->whereNull('assigned_to')->count(),
                'items' => $tasks,
            ],
            'activity' => $interactions->concat($events)->sortByDesc('occurred_at')->values()->take(10)->values(),
            'messages' => $messages,
            'staff' => $staff,
            'finance' => [
                'subscription_plan' => $farm->subscription_plan,
                'payment_status' => $farm->payments()->latest()->value('status'),
                'payment_amount' => $farm->payments()->latest()->value('amount'),
                'payment_currency' => $farm->payments()->latest()->value('currency'),
                'revenue_collected' => (float) $revenueCollected,
                'pending_payments' => $pendingPayments,
            ],
            'alerts' => [
                'new_messages' => $messages->count(),
                'new_orders' => $newOrders,
                'pending_payments' => $pendingPayments,
            ],
        ]]);
    }

    private function authorizeCrmAccess(Request $request): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (! in_array($role, ['admin', 'finance', 'customer_support'], true)) {
            abort(403, 'Only CRM staff can access the dashboard.');
        }
    }
}
