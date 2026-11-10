<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Farm\UpdateSubscriptionRequest;
use App\Http\Resources\FarmResource;
use App\Models\Farm;
use App\Models\Payment;
use App\Models\SubscriptionPlan;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FarmSubscriptionController extends Controller
{
    public function payments(Request $request, Farm $farm): JsonResponse
    {
        $user = $request->user();
        $isOwner = $user->role === 'farmOwner'
            && $user->farms()->where('farms.id', $farm->id)->exists();

        if (! $isOwner) {
            abort(403, 'Only the farm owner can view billing history.');
        }

        $payments = Payment::query()
            ->where('farm_id', $farm->id)
            ->latest()
            ->limit(50)
            ->get()
            ->map(fn (Payment $payment): array => [
                'id' => (string) $payment->id,
                'plan_code' => $payment->plan_code,
                'amount' => $payment->amount,
                'currency' => $payment->currency,
                'status' => $payment->status,
                'receipt' => $payment->mpesa_receipt,
                'description' => $payment->result_description,
                'created_at' => $payment->created_at,
                'paid_at' => $payment->paid_at,
            ]);

        return response()->json(['data' => $payments]);
    }

    public function update(UpdateSubscriptionRequest $request, Farm $farm): JsonResponse
    {
        $user = $request->user();
        $isOwner = $user->role === 'farmOwner'
            && $user->farms()->where('farms.id', $farm->id)->exists();

        if (! $isOwner) {
            abort(403, 'Only the farm owner can choose a subscription.');
        }

        $plan = SubscriptionPlan::where('code', $request->string('plan')->toString())
            ->where('active', true)->first();
        if ($plan === null) {
            abort(422, 'This subscription plan is not available.');
        }

        $farm->update(['subscription_plan' => $plan->code]);

        return response()->json(['farm' => new FarmResource($farm->fresh())]);
    }
}
