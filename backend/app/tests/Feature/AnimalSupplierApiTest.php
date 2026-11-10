<?php

namespace Tests\Feature;

use App\Models\SupplierProfile;
use App\Models\SupplierSubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class AnimalSupplierApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_supplier_can_apply_and_crm_admin_can_approve_and_create_a_plan(): void
    {
        $application = $this->postJson('/api/v1/animal-supplier-applications', $this->applicationData())
            ->assertCreated()
            ->assertJsonPath('application.status', 'pending');
        $profile = SupplierProfile::where('reference', $application->json('application.reference'))->firstOrFail();
        $seller = $profile->user;

        $this->getJson('/api/v1/animal-supplier-subscription-plans')->assertUnauthorized();

        $admin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);
        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/crm/animal-supplier-applications')
            ->assertOk()
            ->assertJsonPath('data.0.business_name', 'Green Barn Supplies');
        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/v1/crm/animal-supplier-applications/{$profile->id}", [
                'status' => 'approved',
                'review_note' => 'Business registration checked.',
            ])
            ->assertOk()
            ->assertJsonPath('application.status', 'approved');
        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/animal-supplier-subscription-plans', [
                'code' => 'supplier-monthly',
                'name' => 'Supplier monthly',
                'description' => 'Product listings for 30 days.',
                'amount' => 600,
                'currency' => 'KES',
                'duration_days' => 30,
            ])
            ->assertCreated()
            ->assertJsonPath('data.code', 'supplier-monthly');

        $this->actingAs($seller, 'sanctum')
            ->getJson('/api/v1/animal-supplier-subscription-plans')
            ->assertOk()
            ->assertJsonPath('data.0.code', 'supplier-monthly');
    }

    public function test_only_approved_sellers_with_active_subscriptions_can_manage_products(): void
    {
        $user = User::factory()->create(['role' => 'animalSupplier']);
        $profile = SupplierProfile::create([
            'user_id' => $user->id,
            'reference' => 'd8218ad2-4cab-49aa-a2d3-316eb0742647',
            'business_registration_number' => 'BRN-2026-001',
            'business_name' => 'Green Barn Supplies',
            'county' => 'Nairobi',
            'product_categories' => 'Feed, medicine, equipment',
            'status' => 'approved',
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/animal-suppliers/products', $this->productData())
            ->assertForbidden();

        $profile->update(['subscription_expires_at' => now()->addDays(30)]);
        $product = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/animal-suppliers/products', $this->productData())
            ->assertCreated()
            ->assertJsonPath('data.name', 'Pig Grower Feed')
            ->assertJsonPath('data.stock_quantity', 25);

        $productId = $product->json('data.id');
        $this->getJson('/api/v1/animal-products?category=Feed&county=Nairobi')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Pig Grower Feed')
            ->assertJsonPath('data.0.supplier_name', 'Green Barn Supplies');
        $this->getJson('/api/v1/animal-suppliers/products')
            ->assertOk()
            ->assertJsonPath('data.0.id', $productId);
        $this->patchJson("/api/v1/animal-suppliers/products/{$productId}", [
            'stock_quantity' => 18,
            'active' => false,
        ])->assertOk()
            ->assertJsonPath('data.stock_quantity', 18)
            ->assertJsonPath('data.active', false);
        $this->getJson('/api/v1/animal-products')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $otherSupplier = User::factory()->create(['role' => 'animalSupplier']);
        SupplierProfile::create([
            'user_id' => $otherSupplier->id,
            'reference' => 'cf38cf71-12b9-4c3d-80e0-a0c0e7e8d926',
            'business_registration_number' => 'BRN-2026-002',
            'business_name' => 'Other Supplier',
            'county' => 'Kiambu',
            'product_categories' => 'Medicine',
            'status' => 'approved',
            'subscription_expires_at' => now()->addDays(30),
        ]);
        $this->actingAs($otherSupplier, 'sanctum')
            ->patchJson("/api/v1/animal-suppliers/products/{$productId}", ['price' => 1])
            ->assertNotFound();
    }

    public function test_supplier_payment_activates_subscription_only_after_a_valid_mpesa_callback(): void
    {
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/stkpushquery/*' => Http::response([
                'ResponseCode' => '0',
                'CheckoutRequestID' => 'supplier-checkout-1',
                'ResultCode' => '0',
            ]),
            'sandbox.safaricom.co.ke/mpesa/*' => Http::response([
                'ResponseCode' => '0',
                'MerchantRequestID' => 'supplier-merchant-1',
                'CheckoutRequestID' => 'supplier-checkout-1',
                'CustomerMessage' => 'Request accepted.',
            ]),
        ]);
        config(['services.mpesa' => [
            'environment' => 'sandbox',
            'consumer_key' => 'key',
            'consumer_secret' => 'secret',
            'shortcode' => '174379',
            'passkey' => 'passkey',
            'callback_url' => 'https://payments.example.com/api/v1/payments/mpesa/callback',
            'callback_secret' => 'test-callback-secret-12345678901234567890',
        ]]);

        $user = User::factory()->create([
            'role' => 'animalSupplier',
            'phone' => '0712345678',
        ]);
        $profile = SupplierProfile::create([
            'user_id' => $user->id,
            'reference' => '97114236-2767-4951-a1b0-cc74f832203d',
            'business_registration_number' => 'BRN-PAY-001',
            'business_name' => 'Green Barn Supplies',
            'county' => 'Nairobi',
            'product_categories' => 'Feed, medicine',
            'status' => 'approved',
        ]);
        SupplierSubscriptionPlan::create([
            'code' => 'supplier-monthly',
            'name' => 'Supplier monthly',
            'amount' => 600,
            'currency' => 'KES',
            'duration_days' => 30,
            'active' => true,
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/animal-suppliers/subscription/payment', [
                'plan' => 'supplier-monthly',
                'phone' => '0712345678',
            ])
            ->assertCreated()
            ->assertJsonPath('payment.status', 'pending')
            ->assertJsonMissingPath('payment.checkout_request_id');
        $paymentId = $response->json('payment.id');

        Http::assertSent(fn ($request): bool => str_ends_with(
            $request->url(),
            '/mpesa/stkpush/v1/processrequest',
        ) && $request['AccountReference'] === 'Supplier-'.$profile->id
            && $request['PhoneNumber'] === '254712345678');

        $callback = ['Body' => ['stkCallback' => [
            'CheckoutRequestID' => 'supplier-checkout-1',
            'ResultCode' => 0,
            'ResultDesc' => 'Payment received.',
            'CallbackMetadata' => ['Item' => [
                ['Name' => 'Amount', 'Value' => 600],
                ['Name' => 'MpesaReceiptNumber', 'Value' => 'SUP123456'],
            ]],
        ]]];

        $this->postJson('/api/v1/payments/mpesa/callback', $callback)->assertForbidden();
        $this->postJson(
            '/api/v1/payments/mpesa/callback?callback_token=test-callback-secret-12345678901234567890',
            $callback,
        )->assertOk();
        $this->getJson("/api/v1/animal-suppliers/payments/{$paymentId}")
            ->assertOk()
            ->assertJsonPath('payment.status', 'paid');
        $this->assertTrue($profile->fresh()->subscription_expires_at->isFuture());
    }

    private function applicationData(): array
    {
        return [
            'name' => 'Sam Supplier',
            'email' => 'seller@example.com',
            'phone' => '+254712345679',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'business_registration_number' => 'BRN-2026-001',
            'business_name' => 'Green Barn Supplies',
            'county' => 'Nairobi',
            'product_categories' => 'Feed, medicine, equipment',
        ];
    }

    private function productData(): array
    {
        return [
            'name' => 'Pig Grower Feed',
            'category' => 'Feed',
            'description' => 'Balanced grower ration.',
            'price' => 2500,
            'currency' => 'KES',
            'unit' => '50 kg bag',
            'stock_quantity' => 25,
        ];
    }
}
