<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Farm;
use App\Models\Payment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CrmReportController extends Controller
{
    public function overview(Request $request): JsonResponse
    {
        $this->authorizeReportAccess($request);
        $farmIds = $request->user()->farms()->pluck('farms.id');
        $farmId = $request->filled('farm_id') ? $request->integer('farm_id') : null;

        if ($farmId !== null && ! $farmIds->contains($farmId)) {
            abort(403, 'You do not have access to this farm.');
        }

        $customers = Customer::query()
            ->whereIn('farm_id', $farmIds)
            ->when($farmId !== null, fn ($query) => $query->where('farm_id', $farmId));
        $total = (clone $customers)->count();
        $statusCounts = (clone $customers)
            ->selectRaw('status, count(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');
        $farms = Farm::query()
            ->whereIn('id', $farmIds)
            ->when($farmId !== null, fn ($query) => $query->whereKey($farmId))
            ->with(['users' => fn ($query) => $query->where('role', 'farmOwner')])
            ->get();
        $farmOwnerCount = $farms->sum(fn (Farm $farm) => $farm->users->count());
        $paidFarmOwnerCount = $farms->sum(function (Farm $farm): int {
            return $farm->users->isNotEmpty() && $farm->payments()->latest('created_at')->value('status') === 'paid' ? $farm->users->count() : 0;
        });
        $revenueCollected = Payment::query()
            ->whereIn('farm_id', $farmIds)
            ->when($farmId !== null, fn ($query) => $query->where('farm_id', $farmId))
            ->where('status', 'paid')
            ->sum('amount');
        $payments = Payment::query()
            ->whereIn('farm_id', $farmIds)
            ->when($farmId !== null, fn ($query) => $query->where('farm_id', $farmId))
            ->with('farm:id,name')
            ->latest()
            ->limit(50)
            ->get()
            ->map(fn (Payment $payment): array => [
                'id' => (string) $payment->id,
                'farm_name' => $payment->farm?->name,
                'plan_code' => $payment->plan_code,
                'amount' => (float) $payment->amount,
                'currency' => $payment->currency,
                'status' => $payment->status,
                'paid_at' => $payment->paid_at?->toIso8601String(),
                'mpesa_receipt' => $payment->mpesa_receipt,
            ]);
        $subscriptions = $farms->map(function (Farm $farm): array {
                $payment = $farm->payments()->latest()->first();

                return [
                    'id' => (string) $farm->id,
                    'name' => $farm->name,
                    'mother_pig_count' => $farm->mother_pig_count,
                    'subscription_plan' => $farm->subscription_plan,
                    'payment_status' => $payment?->status,
                    'payment_amount' => $payment?->amount,
                    'payment_currency' => $payment?->currency,
                    'mpesa_receipt' => $payment?->mpesa_receipt,
                    'paid_at' => $payment?->paid_at?->toIso8601String(),
                ];
            });

        return response()->json([
            'data' => [
                'total_customers' => $total + $farmOwnerCount,
                'active_relationships' => $total - (int) ($statusCounts['lost'] ?? 0) + $paidFarmOwnerCount,
                'qualified' => (int) ($statusCounts['qualified'] ?? 0),
                'won' => (int) ($statusCounts['won'] ?? 0),
                'farm_owners' => $farmOwnerCount,
                'conversion_rate' => ($total + $farmOwnerCount) > 0 ? round(((int) ($statusCounts['won'] ?? 0) / ($total + $farmOwnerCount)) * 100, 2) : 0,
                'revenue_collected' => (float) $revenueCollected,
                'payments' => $payments,
                'by_status' => $statusCounts,
                'subscriptions' => $subscriptions,
                'generated_at' => now()->toIso8601String(),
            ],
        ]);
    }

    private function authorizeReportAccess(Request $request): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);

        if (! in_array($role, ['admin', 'finance'], true)) {
            abort(403, 'Only CRM admins and Finance can access reports.');
        }
    }
}
