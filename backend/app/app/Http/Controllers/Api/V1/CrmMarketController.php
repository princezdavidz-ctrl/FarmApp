<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Farm;
use App\Models\PigListing;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CrmMarketController extends Controller
{
    public function listings(Request $request): JsonResponse
    {
        $user = $request->user();
        $role = $user->crm_role ?? ($user->role === 'farmOwner' ? 'admin' : null);
        abort_unless(
            $user->is_global_crm_admin || in_array($role, ['admin', 'finance', 'customer_support'], true),
            403,
            'Only CRM staff can access marketplace listings.',
        );

        $filters = $request->validate([
            'status' => ['required', Rule::in(['available', 'sold'])],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
        $farmIds = (bool) $user->is_global_crm_admin
            ? Farm::query()->select('id')
            : $user->farms()->select('farms.id');

        $listings = PigListing::query()
            ->with(['farm:id,name,location', 'animal:id,weight_kg'])
            ->withCount('inquiries')
            ->whereIn('farm_id', $farmIds)
            ->where('status', $filters['status'])
            ->when($filters['status'] === 'available', fn ($query) => $query->where('quantity', '>', 0))
            ->latest()
            ->paginate($filters['per_page'] ?? 50);

        return response()->json([
            'data' => $listings->getCollection()->map(fn (PigListing $listing): array => [
                'id' => (string) $listing->id,
                'farm_id' => (string) $listing->farm_id,
                'farm_name' => $listing->farm?->name,
                'farm_location' => $listing->farm?->location,
                'title' => $listing->title,
                'breed' => $listing->breed,
                'age_weeks' => $listing->age_weeks,
                'weight_kg' => $listing->weight_kg ?? $listing->animal?->weight_kg,
                'quantity' => $listing->quantity,
                'price_per_pig' => $listing->price_per_pig,
                'currency' => $listing->currency,
                'location' => $listing->location,
                'status' => $listing->status,
                'inquiries_count' => (int) $listing->inquiries_count,
                'created_at' => $listing->created_at?->toIso8601String(),
            ])->values(),
            'meta' => [
                'current_page' => $listings->currentPage(),
                'last_page' => $listings->lastPage(),
                'per_page' => $listings->perPage(),
                'total' => $listings->total(),
            ],
        ]);
    }
}
