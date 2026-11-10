<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class PigMarketplaceApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_farm_can_publish_listing_and_review_buyer_requests(): void
    {
        Storage::fake('public');
        [$owner, $farm] = $this->farmWithOwner();
        $imagePath = UploadedFile::fake()
            ->create('pig.jpg', 10, 'image/jpeg')
            ->store("animal-images/{$farm->id}", 'public');
        $animal = $farm->animals()->create([
            'created_by' => $owner->id,
            'tag' => 'PIG-010',
            'type' => 'weaner',
            'sex' => 'female',
            'status' => 'active',
            'weight_kg' => 18.5,
            'image_path' => $imagePath,
        ]);

        $listingId = $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/pig-listings", [
                'animal_id' => $animal->id,
                'title' => 'Healthy weaners',
                'breed' => 'Large White',
                'age_weeks' => 10,
                'weight_kg' => 18.5,
                'quantity' => 6,
                'price_per_pig' => 18000,
                'currency' => 'KES',
                'description' => 'Vaccinated and ready for collection.',
            ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'available')
            ->assertJsonPath('data.farm_name', 'Marketplace farm')
            ->assertJsonPath('data.image_url', Storage::disk('public')->url($imagePath))
            ->assertJsonPath('data.weight_kg', '18.50')
            ->json('data.id');

        $this->postJson("/api/v1/marketplace/pigs/{$listingId}/inquiries", [
            'buyer_name' => 'Amina Buyer',
            'phone' => '+254700000005',
            'quantity' => 7,
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('quantity');

        $inquiryId = $this->postJson("/api/v1/marketplace/pigs/{$listingId}/inquiries", [
            'buyer_name' => 'Amina Buyer',
            'phone' => '+254700000005',
            'email' => 'amina@example.com',
            'quantity' => 2,
            'message' => 'Can I collect this weekend?',
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending')
            ->json('data.id');

        $this->getJson('/api/v1/marketplace/pigs')
            ->assertOk()
            ->assertJsonPath('data.0.id', (string) $listingId)
            ->assertJsonPath('data.0.farm_name', 'Marketplace farm')
            ->assertJsonPath('data.0.price_per_pig', '18000.00')
            ->assertJsonPath('data.0.weight_kg', '18.50')
            ->assertJsonPath('data.0.image_url', Storage::disk('public')->url($imagePath))
            ->assertJsonPath('data.0.inquiries', null);

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/farms/{$farm->id}/pig-listings")
            ->assertOk()
            ->assertJsonPath('data.0.inquiries.0.buyer_name', 'Amina Buyer')
            ->assertJsonPath('data.0.inquiries.0.phone', '+254700000005');

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/pig-listings/{$listingId}/inquiries/{$inquiryId}", [
                'status' => 'accepted',
            ])
            ->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/pig-listings/{$listingId}", [
                'status' => 'sold',
            ])
            ->assertOk()
            ->assertJsonPath('data.status', 'sold');

        $this->assertDatabaseHas('pig_inquiries', [
            'id' => $inquiryId,
            'pig_listing_id' => $listingId,
            'status' => 'accepted',
        ]);
    }

    public function test_buyers_cannot_request_unavailable_pigs_and_farms_are_isolated(): void
    {
        [$owner, $farm] = $this->farmWithOwner();
        $listing = $farm->pigListings()->create([
            'title' => 'Breeding gilt',
            'breed' => 'Landrace',
            'quantity' => 1,
            'price_per_pig' => 25000,
            'currency' => 'KES',
            'status' => 'unavailable',
            'created_by' => $owner->id,
        ]);

        $this->postJson("/api/v1/marketplace/pigs/{$listing->id}/inquiries", [
            'buyer_name' => 'Buyer',
            'phone' => '+254700000006',
            'quantity' => 1,
        ])->assertNotFound();

        $otherFarm = Farm::create(['name' => 'Other farm']);
        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/farms/{$otherFarm->id}/pig-listings")
            ->assertForbidden();

        $this->postJson('/api/v1/marketplace/pigs', [
            'title' => 'Invalid public listing',
            'breed' => 'Mixed',
            'quantity' => 1,
            'price_per_pig' => 1,
            'currency' => 'KES',
        ])->assertMethodNotAllowed();
    }

    public function test_crm_market_lists_posted_and_sold_pigs_only_from_accessible_farms(): void
    {
        [$owner, $farm] = $this->farmWithOwner();
        $crmUser = User::factory()->create([
        'role' => 'farmWorker',
        'crm_role' => 'customer_support',
        ]);
        $farm->users()->attach($crmUser->id);
        $otherFarm = Farm::create(['name' => 'Private Market Farm']);

        $posted = $farm->pigListings()->create([
        'title' => 'Posted gilt',
        'breed' => 'Large White',
        'quantity' => 2,
        'price_per_pig' => 18000,
        'currency' => 'KES',
        'created_by' => $owner->id,
        ]);
        $sold = $farm->pigListings()->create([
        'title' => 'Sold boar',
        'breed' => 'Landrace',
        'quantity' => 1,
        'price_per_pig' => 25000,
        'currency' => 'KES',
        'status' => 'sold',
        'created_by' => $owner->id,
        ]);
        $otherFarm->pigListings()->create([
        'title' => 'Hidden listing',
        'breed' => 'Mixed',
        'quantity' => 1,
        'price_per_pig' => 9000,
        'currency' => 'KES',
        'created_by' => $owner->id,
        ]);

        $this->actingAs($crmUser, 'sanctum')
        ->getJson('/api/v1/crm/market/listings?status=available')
        ->assertOk()
        ->assertJsonPath('meta.total', 1)
        ->assertJsonPath('data.0.id', (string) $posted->id)
        ->assertJsonPath('data.0.farm_name', 'Marketplace farm');

        $this->actingAs($crmUser, 'sanctum')
        ->getJson('/api/v1/crm/market/listings?status=sold')
        ->assertOk()
        ->assertJsonPath('meta.total', 1)
        ->assertJsonPath('data.0.id', (string) $sold->id)
        ->assertJsonPath('data.0.status', 'sold');

        $this->actingAs($crmUser, 'sanctum')
        ->getJson('/api/v1/crm/market/listings?status=unavailable')
        ->assertUnprocessable();
    }

    public function test_buyer_can_register_send_purchase_request_and_view_delivery_status(): void
    {
        [$owner, $farm] = $this->farmWithOwner();
        $listing = $farm->pigListings()->create([
            'title' => 'Delivery pig',
            'breed' => 'Large White',
            'age_weeks' => 16,
            'weight_kg' => 95.5,
            'quantity' => 3,
            'price_per_pig' => 21000,
            'currency' => 'KES',
            'created_by' => $owner->id,
        ]);

        $buyerId = $this->postJson('/api/v1/auth/register', [
            'name' => 'Buyer One',
            'email' => 'buyer@example.com',
            'phone' => '+254711000123',
            'password' => 'BuyerPass123',
            'password_confirmation' => 'BuyerPass123',
            'role' => 'buyer',
        ])
            ->assertOk()
            ->assertJsonPath('user.role', 'buyer')
            ->assertJsonPath('farms', [])
            ->json('user.id');

        $this->assertDatabaseHas('buyers', ['user_id' => $buyerId]);
        $buyer = User::findOrFail($buyerId);
        $this->postJson("/api/v1/marketplace/pigs/{$listing->id}/buyer-inquiries", [
            'buyer_name' => $buyer->name,
            'phone' => $buyer->phone,
            'quantity' => 1,
        ])->assertUnauthorized();

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/marketplace/pigs/{$listing->id}/buyer-inquiries", [
                'buyer_name' => 'Farm owner',
                'phone' => '+254700000000',
                'quantity' => 1,
            ])
            ->assertForbidden();

        $inquiryId = $this->actingAs($buyer, 'sanctum')
            ->postJson("/api/v1/marketplace/pigs/{$listing->id}/buyer-inquiries", [
                'buyer_name' => $buyer->name,
                'phone' => $buyer->phone,
                'email' => $buyer->email,
                'quantity' => 2,
                'message' => 'Please arrange delivery.',
            ])
            ->assertCreated()
            ->json('data.id');

        $this->assertDatabaseHas('pig_inquiries', [
            'id' => $inquiryId,
            'buyer_id' => $buyer->buyer->id,
            'buyer_user_id' => $buyer->id,
        ]);

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/farms/{$farm->id}/pig-listings/{$listing->id}/inquiries/{$inquiryId}", [
                'status' => 'accepted',
            ])
            ->assertOk();

        $this->actingAs($buyer, 'sanctum')
            ->getJson('/api/v1/marketplace/buyer/deliveries')
            ->assertOk()
            ->assertJsonPath('data.0.id', (string) $inquiryId)
            ->assertJsonPath('data.0.status', 'accepted')
            ->assertJsonPath('data.0.listing.farm_name', 'Marketplace farm')
            ->assertJsonPath('data.0.listing.age_weeks', 16)
            ->assertJsonPath('data.0.listing.weight_kg', '95.50');

        $this->actingAs(User::factory()->create(['role' => 'buyer']), 'sanctum')
            ->getJson('/api/v1/marketplace/buyer/deliveries')
            ->assertOk()
            ->assertJsonPath('data', []);
    }

    public function test_listing_for_a_herd_animal_exposes_its_saved_photo_to_buyers(): void
    {
        Storage::fake('public');
        [$owner, $farm] = $this->farmWithOwner();
        $imagePath = UploadedFile::fake()
            ->create('pig.jpg', 10, 'image/jpeg')
            ->store("animal-images/{$farm->id}", 'public');
        $animal = $farm->animals()->create([
            'created_by' => $owner->id,
            'tag' => 'PIG-001',
            'type' => 'sow',
            'sex' => 'female',
            'status' => 'active',
            'weight_kg' => 72.5,
            'image_path' => $imagePath,
        ]);

        $listingId = $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/pig-listings", [
                'animal_id' => $animal->id,
                'title' => $animal->tag,
                'breed' => 'sow (female)',
                'quantity' => 1,
                'price_per_pig' => 25000,
                'currency' => 'KES',
            ])
            ->assertCreated()
            ->assertJsonPath('data.animal_id', (string) $animal->id)
            ->assertJsonPath(
                'data.image_url',
                Storage::disk('public')->url($imagePath),
            )
            ->assertJsonPath('data.weight_kg', '72.50')
            ->json('data.id');

        $this->getJson('/api/v1/marketplace/pigs')
            ->assertOk()
            ->assertJsonPath('data.0.id', (string) $listingId)
            ->assertJsonPath('data.0.image_url', Storage::disk('public')->url($imagePath))
            ->assertJsonPath('data.0.weight_kg', '72.50');

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/pig-listings", [
                'animal_id' => $animal->id,
                'title' => $animal->tag,
                'breed' => 'sow (female)',
                'quantity' => 1,
                'price_per_pig' => 25000,
                'currency' => 'KES',
            ])
            ->assertUnprocessable();
    }

    /** @return array{User, Farm} */
    private function farmWithOwner(): array
    {
        $owner = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Marketplace farm', 'location' => 'Nakuru']);
        $farm->users()->attach($owner->id);

        return [$owner, $farm];
    }
}
