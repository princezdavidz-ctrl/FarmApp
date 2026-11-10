<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\VeterinarianProfile;
use App\Models\VeterinarySubscriptionPlan;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class VeterinarianApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_veterinarian_can_submit_an_application_and_check_pending_status(): void
    {
        $response = $this->postJson('/api/v1/veterinary-applications', $this->applicationData())
            ->assertCreated()
            ->assertJsonPath('application.status', 'pending');

        $reference = $response->json('application.reference');
        $this->assertDatabaseHas('users', [
            'email' => 'vet@example.com',
            'role' => 'veterinarian',
        ]);
        $this->assertDatabaseHas('veterinarian_profiles', [
            'reference' => $reference,
            'license_number' => 'VET-2026-001',
            'status' => 'pending',
        ]);

        $this->getJson("/api/v1/veterinary-applications/{$reference}")
            ->assertOk()
            ->assertJsonPath('application.status', 'pending');
    }

    public function test_only_a_crm_administrator_can_approve_a_veterinary_application(): void
    {
        $application = $this->postJson('/api/v1/veterinary-applications', $this->applicationData())
            ->assertCreated();
        $profile = VeterinarianProfile::where('reference', $application->json('application.reference'))->firstOrFail();
        $vet = $profile->user;

        $this->actingAs($vet, 'sanctum')
            ->getJson('/api/v1/veterinary-subscription-plans')
            ->assertForbidden();

        $nonAdmin = User::factory()->create();
        $this->actingAs($nonAdmin, 'sanctum')
            ->patchJson("/api/v1/crm/veterinary-applications/{$profile->id}", ['status' => 'approved'])
            ->assertForbidden();

        $admin = User::factory()->create(['role' => 'farmOwner', 'crm_role' => 'admin']);
        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/crm/veterinary-applications')
            ->assertOk()
            ->assertJsonPath('data.0.reference', $profile->reference);

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/v1/crm/veterinary-applications/{$profile->id}", [
                'status' => 'approved',
                'review_note' => 'License verified.',
            ])
            ->assertOk()
            ->assertJsonPath('application.status', 'approved');

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/crm/veterinary-subscription-plans', [
                'code' => 'vet-monthly',
                'name' => 'Monthly veterinary access',
                'description' => 'Professional account access for 30 days.',
                'amount' => 750,
                'currency' => 'KES',
                'duration_days' => 30,
            ])
            ->assertCreated()
            ->assertJsonPath('data.code', 'vet-monthly');

        $this->actingAs($vet, 'sanctum')
            ->getJson('/api/v1/veterinary-subscription-plans')
            ->assertOk()
            ->assertJsonPath('data.0.code', 'vet-monthly')
            ->assertJsonPath('data.0.amount', '750.00');
    }

    public function test_approved_veterinarian_can_start_mpesa_subscription_payment(): void
    {
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/stkpushquery/*' => Http::response([
                'ResponseCode' => '0',
                'CheckoutRequestID' => 'vet-checkout-1',
                'ResultCode' => '0',
            ]),
            'sandbox.safaricom.co.ke/mpesa/*' => Http::response([
                'ResponseCode' => '0',
                'MerchantRequestID' => 'vet-merchant-1',
                'CheckoutRequestID' => 'vet-checkout-1',
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
            'role' => 'veterinarian',
            'phone' => '0712345678',
        ]);
        $profile = VeterinarianProfile::create([
            'user_id' => $user->id,
            'reference' => '76fc34ad-6168-44b0-96bc-a3bec9b207c2',
            'license_number' => 'VET-PAY-001',
            'clinic_name' => 'County Veterinary Clinic',
            'county' => 'Nairobi',
            'status' => 'approved',
            'reviewed_at' => now(),
        ]);
        VeterinarySubscriptionPlan::create([
            'code' => 'vet-monthly',
            'name' => 'Monthly veterinary access',
            'amount' => 750,
            'currency' => 'KES',
            'duration_days' => 30,
            'active' => true,
        ]);

        $paymentResponse = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/veterinarians/subscription/payment', [
                'plan' => 'vet-monthly',
                'phone' => '0712345678',
            ])
            ->assertCreated()
            ->assertJsonPath('payment.status', 'pending')
            ->assertJsonPath('payment.amount', '750.00')
            ->assertJsonMissingPath('payment.checkout_request_id');

        $paymentId = $paymentResponse->json('payment.id');
        Http::assertSent(fn ($request): bool => str_ends_with(
            $request->url(),
            '/mpesa/stkpush/v1/processrequest',
        ) && $request['AccountReference'] === 'Vet-'.$profile->id
            && $request['PhoneNumber'] === '254712345678');

        $callback = [
            'Body' => [
                'stkCallback' => [
                    'CheckoutRequestID' => 'vet-checkout-1',
                    'ResultCode' => 0,
                    'ResultDesc' => 'The service request is processed successfully.',
                    'CallbackMetadata' => [
                        'Item' => [
                            ['Name' => 'Amount', 'Value' => 750],
                            ['Name' => 'MpesaReceiptNumber', 'Value' => 'QWE1234567'],
                        ],
                    ],
                ],
            ],
        ];
        $this->postJson('/api/v1/payments/mpesa/callback', $callback)->assertForbidden();
        $this->postJson(
            '/api/v1/payments/mpesa/callback?callback_token=test-callback-secret-12345678901234567890',
            $callback,
        )->assertOk();

        $this->getJson("/api/v1/veterinarians/payments/{$paymentId}")
            ->assertOk()
            ->assertJsonPath('payment.status', 'paid');
        $this->assertNotNull($profile->fresh()->subscription_expires_at);
        $this->getJson('/api/v1/veterinarians/me')
            ->assertOk()
            ->assertJsonPath('veterinarian.status', 'approved')
            ->assertJsonPath('veterinarian.subscription_expires_at', $profile->fresh()->subscription_expires_at->toIso8601String());
    }

    private function applicationData(): array
    {
        return [
            'name' => 'Dr Vet',
            'email' => 'vet@example.com',
            'phone' => '+254712345678',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'license_number' => 'VET-2026-001',
            'clinic_name' => 'Pig Care Veterinary Clinic',
            'county' => 'Nairobi',
            'specialization' => 'Pig health',
            'years_experience' => 8,
        ];
    }
}
