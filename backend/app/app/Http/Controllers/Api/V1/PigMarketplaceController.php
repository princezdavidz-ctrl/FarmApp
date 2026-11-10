<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Marketplace\StorePigInquiryRequest;
use App\Http\Requests\Marketplace\StorePigListingRequest;
use App\Models\Animal;
use App\Models\Buyer;
use App\Models\Farm;
use App\Models\PigInquiry;
use App\Models\PigListing;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class PigMarketplaceController extends Controller
{
    public function browse(Request $request): JsonResponse
    {
        $listings = PigListing::query()
            ->where('status', 'available')
            ->where('quantity', '>', 0)
            ->with(['farm:id,name,location', 'animal'])
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = $request->string('search')->toString();
                $query->where(fn ($listings) => $listings
                    ->where('title', 'like', "%{$term}%")
                    ->orWhere('breed', 'like', "%{$term}%")
                    ->orWhere('location', 'like', "%{$term}%")
                    ->orWhereHas('farm', fn ($farm) => $farm->where('name', 'like', "%{$term}%")
                        ->orWhere('location', 'like', "%{$term}%")));
            })
            ->latest()
            ->limit(100)
            ->get();

        return response()->json(['data' => $listings->map(fn (PigListing $listing) => $this->listingData($listing))]);
    }

    public function inquire(StorePigInquiryRequest $request, PigListing $listing): JsonResponse
    {
        return $this->createInquiry($request, $listing);
    }

    public function buyerInquire(StorePigInquiryRequest $request, PigListing $listing): JsonResponse
    {
        abort_unless($request->user()?->role === 'buyer', 403, 'Only buyer accounts can send authenticated requests.');

        $buyer = $request->user()->buyer()->firstOrCreate([]);

        return $this->createInquiry($request, $listing, $buyer);
    }

    public function buyerDeliveries(Request $request): JsonResponse
    {
        abort_unless($request->user()?->role === 'buyer', 403, 'Only buyer accounts can view buyer requests.');
        $buyer = $request->user()->buyer()->firstOrCreate([]);
        $inquiries = PigInquiry::query()
            ->where(function ($query) use ($buyer, $request): void {
                $query->where('buyer_id', $buyer->id)
                    ->orWhere('buyer_user_id', $request->user()->id);
            })
            ->with(['listing.farm:id,name,location'])
            ->latest()
            ->limit(200)
            ->get();

        return response()->json([
            'data' => $inquiries->map(fn (PigInquiry $inquiry) => $this->buyerDeliveryData($inquiry)),
        ]);
    }

    private function createInquiry(StorePigInquiryRequest $request, PigListing $listing, ?Buyer $buyer = null): JsonResponse
    {
        abort_unless($listing->status === 'available' && $listing->quantity > 0, 404);
        if ($request->integer('quantity') > $listing->quantity) {
            throw ValidationException::withMessages([
                'quantity' => ['The requested quantity is greater than the number of pigs available.'],
            ]);
        }
        $inquiry = $listing->inquiries()->create($request->validated() + [
            'buyer_id' => $buyer?->id,
            'buyer_user_id' => $buyer?->user_id,
        ]);
        $inquiry->refresh();

        return response()->json([
            'data' => [
                'id' => (string) $inquiry->id,
                'status' => $inquiry->status,
                'message' => 'Your request has been sent to the farm.',
            ],
        ], 201);
    }

    public function farmListings(Request $request, Farm $farm): JsonResponse
    {
        $this->authorizeFarmSales($request, $farm);
        $listings = $farm->pigListings()
            ->with(['farm:id,name,location', 'animal', 'inquiries' => fn ($query) => $query->latest()])
            ->latest()
            ->limit(100)
            ->get();

        return response()->json(['data' => $listings->map(fn (PigListing $listing) => $this->listingData($listing, true))]);
    }

    public function store(StorePigListingRequest $request, Farm $farm): JsonResponse
    {
        $this->authorizeFarmSales($request, $farm, write: true);
        $data = $request->validated();
        $animal = Animal::query()
            ->where('farm_id', $farm->id)
            ->findOrFail($data['animal_id']);
        abort_unless($animal->status === 'active', 422, 'Only active pigs can be posted.');
        abort_unless($animal->image_path !== null, 422, 'Add a photo to this pig in Herd before posting it.');
        if (($data['weight_kg'] ?? null) === null && $animal->weight_kg === null) {
            throw ValidationException::withMessages([
                'weight_kg' => ['Add the pig weight in Herd or enter its weight in the listing.'],
            ]);
        }
        $data['weight_kg'] ??= $animal->weight_kg;
        $alreadyPosted = $farm->pigListings()
            ->where('animal_id', $animal->id)
            ->where('status', 'available')
            ->exists();
        abort_if($alreadyPosted, 422, 'This pig already has an active listing.');
        $listing = $farm->pigListings()->create($data + [
            'created_by' => $request->user()->id,
            'location' => $request->validated('location') ?: $farm->location,
        ]);

        return response()->json([
            'data' => $this->listingData($listing->fresh()->load(['farm:id,name,location', 'animal']), true),
        ], 201);
    }

    public function updateStatus(Request $request, Farm $farm, PigListing $listing): JsonResponse
    {
        $this->authorizeFarmSales($request, $farm, write: true);
        abort_unless((int) $listing->farm_id === (int) $farm->id, 404);
        $data = $request->validate(['status' => ['required', Rule::in(['available', 'unavailable', 'sold'])]]);
        $listing->update($data);

        return response()->json(['data' => $this->listingData($listing->fresh()->load(['farm:id,name,location', 'animal', 'inquiries']), true)]);
    }

    public function updateInquiryStatus(Request $request, Farm $farm, PigListing $listing, PigInquiry $inquiry): JsonResponse
    {
        $this->authorizeFarmSales($request, $farm, write: true);
        abort_unless((int) $listing->farm_id === (int) $farm->id, 404);
        abort_unless((int) $inquiry->pig_listing_id === (int) $listing->id, 404);
        $data = $request->validate(['status' => ['required', Rule::in(['pending', 'accepted', 'rejected', 'completed'])]]);
        $inquiry->update($data);

        return response()->json(['data' => $this->inquiryData($inquiry->fresh())]);
    }

    private function authorizeFarmSales(Request $request, Farm $farm, bool $write = false): void
    {
        $user = $request->user();
        $membership = $user->farms()->where('farms.id', $farm->id)->first();
        abort_if($membership === null, 403, 'You do not have access to this farm.');
        abort_if($user->crm_closed_at !== null, 403, 'This CRM account is inactive.');

        if ($user->role === 'farmOwner') {
            return;
        }

        $crmRole = $user->crm_role;
        if (in_array($crmRole, ['admin', 'finance', 'customer_support'], true)) {
            abort_if($write && ! in_array($crmRole, ['admin', 'finance'], true), 403);

            return;
        }

        $permissions = $membership->pivot->permissions === null
            ? match ($user->role) {
                'farmManager', 'salesMarketing' => ['viewSales', 'manageSales'],
                'accountant' => ['viewSales'],
                default => [],
            }
        : json_decode($membership->pivot->permissions, true);
        $canManage = in_array('manageSales', $permissions ?? [], true);
        $canView = $canManage || in_array('viewSales', $permissions ?? [], true);
        abort_unless($write ? $canManage : $canView, 403);
    }

    private function listingData(PigListing $listing, bool $withInquiries = false): array
    {
        $data = [
            'id' => (string) $listing->id,
            'animal_id' => $listing->animal_id === null ? null : (string) $listing->animal_id,
            'image_url' => $listing->animal?->image_path === null
                ? null
                : Storage::disk('public')->url($listing->animal->image_path),
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
            'description' => $listing->description,
            'status' => $listing->status,
            'created_at' => $listing->created_at?->toIso8601String(),
        ];
        if ($withInquiries) {
            $data['inquiries'] = $listing->inquiries->map(fn (PigInquiry $inquiry) => $this->inquiryData($inquiry))->all();
        }

        return $data;
    }

    private function inquiryData(PigInquiry $inquiry): array
    {
        return [
            'id' => (string) $inquiry->id,
            'buyer_name' => $inquiry->buyer_name,
            'phone' => $inquiry->phone,
            'email' => $inquiry->email,
            'quantity' => $inquiry->quantity,
            'message' => $inquiry->message,
            'status' => $inquiry->status,
            'created_at' => $inquiry->created_at?->toIso8601String(),
        ];
    }

    private function buyerDeliveryData(PigInquiry $inquiry): array
    {
        $listing = $inquiry->listing;

        return [
            ...$this->inquiryData($inquiry),
            'listing' => $listing === null ? null : [
                'id' => (string) $listing->id,
                'title' => $listing->title,
                'breed' => $listing->breed,
                'age_weeks' => $listing->age_weeks,
                'weight_kg' => $listing->weight_kg ?? $listing->animal?->weight_kg,
                'price_per_pig' => $listing->price_per_pig,
                'currency' => $listing->currency,
                'image_url' => $listing->animal?->image_path === null
                    ? null
                    : Storage::disk('public')->url($listing->animal->image_path),
                'location' => $listing->location,
                'farm_name' => $listing->farm?->name,
                'farm_location' => $listing->farm?->location,
            ],
        ];
    }
}
