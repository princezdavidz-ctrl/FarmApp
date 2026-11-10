<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\Crm\CustomerInteractionResource;
use App\Models\Customer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class CrmCustomerEventController extends Controller
{
    public function timeline(Request $request, Customer $customer): JsonResponse
    {
        $this->authorizeCustomer($request, $customer);

        $interactions = $customer->interactions()->with('user:id,name')->get()->map(fn ($item) => [
            'id' => 'interaction-'.$item->id,
            'type' => 'interaction',
            'subtype' => $item->type,
            'notes' => $item->notes,
            'user' => $item->user ? ['id' => (string) $item->user->id, 'name' => $item->user->name] : null,
            'occurred_at' => $item->occurred_at?->toIso8601String(),
        ]);

        $events = $customer->events()->with('user:id,name')->get()->map(fn ($item) => [
            'id' => 'event-'.$item->id,
            'type' => $item->type,
            'subtype' => null,
            'notes' => null,
            'data' => $item->data,
            'user' => $item->user ? ['id' => (string) $item->user->id, 'name' => $item->user->name] : null,
            'occurred_at' => $item->occurred_at?->toIso8601String(),
        ]);

        return response()->json(['data' => $interactions->concat($events)->sortByDesc('occurred_at')->values()]);
    }

    private function authorizeCustomer(Request $request, Customer $customer): void
    {
        $role = $request->user()->crm_role ?? ($request->user()->role === 'farmOwner' ? 'admin' : null);
        if (! in_array($role, ['admin', 'finance', 'customer_support'], true)) {
            abort(403, 'Only CRM staff can access customer timelines.');
        }
        if (! $request->user()->farms()->where('farms.id', $customer->farm_id)->exists()) {
            throw ValidationException::withMessages(['farm_id' => ['You do not have access to this farm.']]);
        }
    }
}
