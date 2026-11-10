<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\StoreFarmFinanceTransactionRequest;
use App\Models\Farm;
use App\Models\FarmFinanceTransaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FarmFinanceController extends Controller
{
    public function index(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeFinance($request, $farm);
        $today = now()->toDateString();
        $periodStart = now()->startOfMonth()->toDateString();
        $limit = min(max($request->integer('limit', 100), 1), 250);
        $transactions = $farm->financeTransactions()
            ->latest('occurred_at')
            ->latest('id')
            ->limit($limit)
            ->get();

        $totals = $farm->financeTransactions()
            ->whereDate('occurred_at', '>=', $periodStart)
            ->whereDate('occurred_at', '<=', $today)
            ->select('currency')
            ->selectRaw("SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) AS income")
            ->selectRaw("SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS expenses")
            ->groupBy('currency')
            ->orderBy('currency')
            ->get()
            ->map(fn ($row): array => [
                'currency' => $row->currency,
                'income' => (float) $row->income,
                'expenses' => (float) $row->expenses,
                'profit' => round((float) $row->income - (float) $row->expenses, 2),
            ]);

        return response()->json([
            'summary' => [
                'period_start' => $periodStart,
                'period_end' => $today,
                'totals' => $totals,
            ],
            'data' => $transactions->map(fn (FarmFinanceTransaction $transaction): array => $this->serialize($transaction)),
        ]);
    }

    public function store(StoreFarmFinanceTransactionRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeFinance($request, $farm, write: true);
        $data = $request->validated();
        $data['currency'] = strtoupper($data['currency']);

        $transaction = $farm->financeTransactions()->create($data + [
            'created_by' => $request->user()->id,
        ]);

        return response()->json(['data' => $this->serialize($transaction)], 201);
    }

    private function serialize(FarmFinanceTransaction $transaction): array
    {
        return [
            'id' => (string) $transaction->id,
            'farm_id' => (string) $transaction->farm_id,
            'type' => $transaction->type,
            'category' => $transaction->category,
            'description' => $transaction->description,
            'amount' => (float) $transaction->amount,
            'currency' => $transaction->currency,
            'occurred_at' => $transaction->occurred_at->toDateString(),
            'created_by' => $transaction->created_by === null ? null : (string) $transaction->created_by,
            'created_at' => $transaction->created_at?->toIso8601String(),
        ];
    }

    private function authorizeFinance(Request $request, Farm $farm, bool $write = false): void
    {
        $user = $request->user();
        $membership = $user->farms()->where('farms.id', $farm->id)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');
        abort_if($user->crm_closed_at !== null, 403, 'This account is inactive.');

        if ($user->role === 'farmOwner' || in_array($user->crm_role, ['admin', 'finance'], true)) {
            return;
        }

        $permissions = $membership->pivot->permissions === null
            ? ($user->role === 'accountant' ? ['manageFinance'] : [])
            : json_decode($membership->pivot->permissions, true);
        $canManage = in_array('manageFinance', $permissions ?? [], true);

        abort_unless($canManage, 403, $write
            ? 'You do not have permission to manage farm finances.'
            : 'You do not have permission to view farm finances.');
    }
}
