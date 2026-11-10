<?php

namespace Tests\Feature;

use App\Models\DriverProfile;
use App\Models\DriverSubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class AnimalDriverApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_driver_can_apply_and_crm_admin_can_approve_and_create_a_plan(): void
    {
        $application = $this->postJson('/api/v1/animal-driver-applications', $this->applicationData())
            ->assertCreated()
            ->assertJsonPath('application.status', 'pending');
        $profile = DriverProfile::where('reference', $application->json('application.reference'))->firstOrFail();
        $driver = $profile->user;

        $this->getJson('/api/v1/animal-driver-subscription-plans')->assertUnauthorized();
        $admin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);
        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/crm/animal-driver-applications')
            ->assertOk()
            ->assertJsonPath('data.0.vehicle_registration_number', 'KAA123A');
        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/v1/crm/animal-driver-applications/{$profile->id}", [
                'status' => 'approved',
                'review_note' => 'Licence and vehicle checked.',
            ])
            ->assertOk()
            ->assertJsonPath('application.status', 'approved');
        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/animal-driver-subscription-plans', [
                'code' => 'driver-monthly',
                'name' => 'Driver monthly',
                'amount' => 500,
                'currency' => 'KES',
                'duration_days' => 30,
            ])
            ->assertCreated()
            ->assertJsonPath('data.code', 'driver-monthly');
        $this->actingAs($driver, 'sanctum')
            ->getJson('/api/v1/animal-driver-subscription-plans')
            ->assertOk()
            ->assertJsonPath('data.0.code', 'driver-monthly');
    }

    public function test_only_approved_subscribed_drivers_can_share_location_and_appear_nearby(): void
    {
        $user = User::factory()->create(['role' => 'animalDriver']);
        $profile = $this->createProfile($user, [
            'status' => 'approved',
            'subscription_expires_at' => now()->addDays(30),
        ]);
        $payload = ['latitude' => -1.2864, 'longitude' => 36.8172, 'available' => true];

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/animal-drivers/location', $payload)
            ->assertOk()
            ->assertJsonPath('driver.available', true);
        $this->getJson('/api/v1/animal-drivers/nearby?latitude=-1.2864&longitude=36.8172&service_type=herd')
            ->assertOk()
            ->assertJsonPath('data.0.name', $user->name)
            ->assertJsonPath('data.0.vehicle_type', 'Livestock lorry');
        $profile->update(['location_updated_at' => now()->subMinutes(16)]);
        $this->getJson('/api/v1/animal-drivers/nearby?latitude=-1.2864&longitude=36.8172')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/animal-drivers/location', [
                ...$payload,
                'latitude' => 91,
            ])
            ->assertUnprocessable();
        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/animal-drivers/location', [
                ...$payload,
                'available' => false,
            ])
            ->assertOk();
        $this->getJson('/api/v1/animal-drivers/nearby?latitude=-1.2864&longitude=36.8172')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $profile->update(['subscription_expires_at' => now()->subMinute()]);
        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/animal-drivers/location', $payload)
            ->assertForbidden();
    }

    public function test_driver_subscription_activates_only_after_valid_mpesa_callback(): void
    {
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/*' => Http::response([
                'ResponseCode' => '0',
                'MerchantRequestID' => 'driver-merchant-1',
                'CheckoutRequestID' => 'driver-checkout-1',
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
            'role' => 'animalDriver',
            'phone' => '0712345678',
        ]);
        $profile = $this->createProfile($user, ['status' => 'approved']);
        DriverSubscriptionPlan::create([
            'code' => 'driver-monthly',
            'name' => 'Driver monthly',
            'amount' => 500,
            'currency' => 'KES',
            'duration_days' => 30,
            'active' => true,
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/animal-drivers/subscription/payment', [
                'plan' => 'driver-monthly',
                'phone' => '0712345678',
            ])
            ->assertCreated()
            ->assertJsonPath('payment.status', 'pending')
            ->assertJsonMissingPath('payment.checkout_request_id');
        $paymentId = $response->json('payment.id');

        Http::assertSent(fn ($request): bool => str_ends_with(
            $request->url(),
            '/mpesa/stkpush/v1/processrequest',
        ) && $request['AccountReference'] === 'Driver-'.$profile->id
            && $request['PhoneNumber'] === '254712345678');

        $callback = ['Body' => ['stkCallback' => [
            'CheckoutRequestID' => 'driver-checkout-1',
            'ResultCode' => 0,
            'ResultDesc' => 'Payment received.',
            'CallbackMetadata' => ['Item' => [
                ['Name' => 'MpesaReceiptNumber', 'Value' => 'DRV123456'],
            ]],
        ]]];
        $this->postJson('/api/v1/payments/mpesa/callback', $callback)->assertForbidden();
        $this->postJson(
            '/api/v1/payments/mpesa/callback?callback_token=test-callback-secret-12345678901234567890',
            $callback,
        )->assertOk();
        $this->getJson("/api/v1/animal-drivers/payments/{$paymentId}")
            ->assertOk()
            ->assertJsonPath('payment.status', 'paid');
        $this->assertTrue($profile->fresh()->subscription_expires_at->isFuture());
    }

    private function applicationData(): array
    {
        return [
            'name' => 'Driver Applicant',
            'email' => 'driver@example.com',
            'phone' => '0711111111',
            'password' => 'driver-password',
            'password_confirmation' => 'driver-password',
            'driver_license_number' => 'DL-2026-001',
            'county' => 'Nairobi',
            'service_types' => ['herd', 'supplies'],
            'vehicle_type' => 'Livestock lorry',
            'vehicle_registration_number' => 'KAA123A',
            'capacity_description' => 'Up to 20 pigs or 2 tonnes of supplies',
        ];
    }

    private function createProfile(User $user, array $overrides = []): DriverProfile
    {
        return DriverProfile::create([
            'user_id' => $user->id,
            'reference' => fake()->uuid(),
            'driver_license_number' => 'DL-'.fake()->unique()->numerify('#####'),
            'county' => 'Nairobi',
            'service_types' => 'herd,supplies',
            'vehicle_type' => 'Livestock lorry',
            'vehicle_registration_number' => 'KBB'.fake()->unique()->numerify('###').'A',
            'capacity_description' => 'Up to 20 animals',
            ...$overrides,
        ]);
    }
}
