<?php

namespace Tests\Feature;

use App\Models\Farm;
use App\Models\Payment;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class MpesaPaymentApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_start_a_herd_based_mpesa_payment(): void
    {
        Carbon::setTestNow('2026-10-07 09:00:00');
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/*' => Http::response([
                'ResponseCode' => 0,
                'MerchantRequestID' => 'merchant-1',
                'CheckoutRequestID' => 'checkout-1',
                'CustomerMessage' => 'Success. Request accepted for processing.',
            ]),
        ]);
        $user = User::factory()->create(['role' => 'farmOwner', 'phone' => '254712345678']);
        $farm = Farm::create(['name' => 'Herd Farm', 'mother_pig_count' => 40]);
        $user->farms()->attach($farm);
        SubscriptionPlan::create([
            'code' => 'starter', 'name' => 'Starter', 'amount' => 500,
            'currency' => 'KES', 'pig_limit' => 50, 'active' => true,
        ]);
        config(['services.mpesa' => [
            'environment' => 'sandbox',
            'consumer_key' => 'key', 'consumer_secret' => 'secret',
            'shortcode' => '174379', 'passkey' => 'passkey',
            'callback_url' => 'https://payments.example.com/api/v1/payments/mpesa/callback',
            'callback_secret' => 'test-callback-secret-12345678901234567890',
        ]]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/subscription/payment", ['plan' => 'starter'])
            ->assertCreated()
            ->assertJsonPath('payment.status', 'pending')
            ->assertJsonPath('payment.mother_pig_count', 40)
            ->assertJsonPath('payment.amount', '500.00');

        Http::assertSent(fn ($request) => $request->url() === 'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest'
            && $request['BusinessShortCode'] === '174379'
            && $request['PartyB'] === '174379'
            && $request['Timestamp'] === '20261007090000'
            && $request['Password'] === base64_encode('174379passkey20261007090000')
            && $request['TransactionType'] === 'CustomerPayBillOnline'
            && $request['Amount'] === 500
            && $request['PhoneNumber'] === '254712345678'
            && $request['CallBackURL'] === 'https://payments.example.com/api/v1/payments/mpesa/callback?callback_token=test-callback-secret-12345678901234567890');
        Carbon::setTestNow();
    }

    public function test_till_shortcode_uses_the_buy_goods_transaction_type(): void
    {
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/*' => Http::response([
                'ResponseCode' => '0',
                'MerchantRequestID' => 'merchant-buy-goods',
                'CheckoutRequestID' => 'checkout-buy-goods',
            ]),
        ]);
        $user = User::factory()->create(['role' => 'farmOwner', 'phone' => '254712345678']);
        $farm = Farm::create(['name' => 'Till Farm', 'mother_pig_count' => 5]);
        $user->farms()->attach($farm);
        SubscriptionPlan::create([
            'code' => 'starter', 'name' => 'Starter', 'amount' => 500,
            'currency' => 'KES', 'pig_limit' => 50, 'active' => true,
        ]);
        config(['services.mpesa' => [
            'environment' => 'sandbox',
            'consumer_key' => 'key',
            'consumer_secret' => 'secret',
            'shortcode' => '600000',
            'passkey' => 'passkey',
            'transaction_type' => 'CustomerBuyGoodsOnline',
            'callback_url' => 'https://payments.example.com/api/v1/payments/mpesa/callback',
            'callback_secret' => 'test-callback-secret-12345678901234567890',
        ]]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/subscription/payment", ['plan' => 'starter'])
            ->assertCreated();

        Http::assertSent(fn ($request) => str_ends_with($request->url(), '/mpesa/stkpush/v1/processrequest')
            && $request['BusinessShortCode'] === '600000'
            && $request['PartyB'] === '600000'
            && $request['TransactionType'] === 'CustomerBuyGoodsOnline'
            && $request['Password'] === base64_encode(
                '600000passkey'.now()->format('YmdHis'),
            ));
    }

    public function test_invalid_shortcode_is_rejected_before_contacting_safaricom(): void
    {
        Http::fake();
        $user = User::factory()->create(['role' => 'farmOwner', 'phone' => '254712345678']);
        $farm = Farm::create(['name' => 'Invalid Config Farm', 'mother_pig_count' => 5]);
        $user->farms()->attach($farm);
        SubscriptionPlan::create([
            'code' => 'starter', 'name' => 'Starter', 'amount' => 500,
            'currency' => 'KES', 'pig_limit' => 50, 'active' => true,
        ]);
        config(['services.mpesa' => [
            'environment' => 'sandbox',
            'consumer_key' => 'key',
            'consumer_secret' => 'secret',
            'shortcode' => '17 4379',
            'passkey' => 'passkey',
            'transaction_type' => 'CustomerPayBillOnline',
            'callback_url' => 'https://payments.example.com/api/v1/payments/mpesa/callback',
            'callback_secret' => 'test-callback-secret-12345678901234567890',
        ]]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/subscription/payment", ['plan' => 'starter'])
            ->assertStatus(503)
            ->assertJsonPath('error', 'mpesa_configuration_error');

        Http::assertNothingSent();
    }

    public function test_payment_normalizes_a_kenyan_phone_number_before_sending_the_stk_push(): void
    {
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/*' => Http::response([
                'ResponseCode' => '0', 'MerchantRequestID' => 'merchant-2',
                'CheckoutRequestID' => 'checkout-2',
            ]),
        ]);
        $user = User::factory()->create(['role' => 'farmOwner', 'phone' => '0712 345 678']);
        $farm = Farm::create(['name' => 'Herd Farm', 'mother_pig_count' => 5]);
        $user->farms()->attach($farm);
        SubscriptionPlan::create([
            'code' => 'starter', 'name' => 'Starter', 'amount' => 500,
            'currency' => 'KES', 'pig_limit' => 50, 'active' => true,
        ]);
        config(['services.mpesa' => [
            'environment' => 'sandbox', 'consumer_key' => 'key', 'consumer_secret' => 'secret',
            'shortcode' => '174379', 'passkey' => 'passkey',
            'callback_url' => 'https://payments.example.com/api/v1/payments/mpesa/callback',
            'callback_secret' => 'test-callback-secret-12345678901234567890',
        ]]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/subscription/payment", ['plan' => 'starter'])
            ->assertCreated();

        Http::assertSent(fn ($request) => $request->url() === 'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest'
            && $request['PhoneNumber'] === '254712345678');
    }

    public function test_payment_uses_the_app_supplied_phone_number_when_present(): void
    {
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/*' => Http::response([
                'ResponseCode' => '0', 'MerchantRequestID' => 'merchant-3',
                'CheckoutRequestID' => 'checkout-3',
                'CustomerMessage' => 'Prompt sent to 0746933820.',
            ]),
        ]);
        $user = User::factory()->create(['role' => 'farmOwner', 'phone' => '254700000000']);
        $farm = Farm::create(['name' => 'Prompt Farm', 'mother_pig_count' => 6]);
        $user->farms()->attach($farm);
        SubscriptionPlan::create([
            'code' => 'starter', 'name' => 'Starter', 'amount' => 500,
            'currency' => 'KES', 'pig_limit' => 50, 'active' => true,
        ]);
        config(['services.mpesa' => [
            'environment' => 'sandbox', 'consumer_key' => 'key', 'consumer_secret' => 'secret',
            'shortcode' => '174379', 'passkey' => 'passkey',
            'callback_url' => 'https://payments.example.com/api/v1/payments/mpesa/callback',
            'callback_secret' => 'test-callback-secret-12345678901234567890',
        ]]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/subscription/payment", [
                'plan' => 'starter',
                'phone' => '0746933820',
            ])
            ->assertCreated();

        Http::assertSent(fn ($request) => $request->url() === 'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest'
            && $request['PhoneNumber'] === '254746933820');
    }

    public function test_successful_provider_response_without_checkout_id_is_not_reported_as_a_sent_prompt(): void
    {
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/*' => Http::response([
                'ResponseCode' => '0',
                'MerchantRequestID' => 'merchant-without-checkout',
            ]),
        ]);
        $user = User::factory()->create(['role' => 'farmOwner', 'phone' => '254712345678']);
        $farm = Farm::create(['name' => 'Incomplete Prompt Farm', 'mother_pig_count' => 5]);
        $user->farms()->attach($farm);
        SubscriptionPlan::create([
            'code' => 'starter', 'name' => 'Starter', 'amount' => 500,
            'currency' => 'KES', 'pig_limit' => 50, 'active' => true,
        ]);
        config(['services.mpesa' => [
            'environment' => 'sandbox', 'consumer_key' => 'key', 'consumer_secret' => 'secret',
            'shortcode' => '174379', 'passkey' => 'passkey',
            'callback_url' => 'https://payments.example.com/api/v1/payments/mpesa/callback',
            'callback_secret' => 'test-callback-secret-12345678901234567890',
        ]]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/subscription/payment", ['plan' => 'starter'])
            ->assertStatus(503)
            ->assertJsonPath('error', 'mpesa_configuration_error');

        $this->assertDatabaseHas('payments', [
            'farm_id' => $farm->id,
            'status' => 'failed',
            'checkout_request_id' => null,
        ]);
    }

    public function test_safaricom_server_error_is_returned_as_a_safe_gateway_error(): void
    {
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/*' => Http::response([
                'requestId' => 'safe-reference-123',
                'errorCode' => '500.001.1001',
                'errorMessage' => 'Internal provider error',
            ], 500),
        ]);
        $user = User::factory()->create(['role' => 'farmOwner', 'phone' => '254712345678']);
        $farm = Farm::create(['name' => 'Gateway Error Farm', 'mother_pig_count' => 5]);
        $user->farms()->attach($farm);
        SubscriptionPlan::create([
            'code' => 'starter', 'name' => 'Starter', 'amount' => 500,
            'currency' => 'KES', 'pig_limit' => 50, 'active' => true,
        ]);
        config(['services.mpesa' => [
            'environment' => 'sandbox', 'consumer_key' => 'secret-key', 'consumer_secret' => 'secret-value',
            'shortcode' => '174379', 'passkey' => 'secret-passkey',
            'callback_url' => 'https://api.example.com/api/v1/payments/mpesa/callback',
            'callback_secret' => 'test-callback-secret-12345678901234567890',
        ]]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/farms/{$farm->id}/subscription/payment", [
                'plan' => 'starter',
                'phone' => '0746933820',
            ])
            ->assertStatus(502)
            ->assertJsonPath('error', 'mpesa_upstream_error')
            ->assertJsonPath('provider_code', '500.001.1001')
            ->assertJsonPath('reference', 'safe-reference-123')
            ->assertDontSee('secret-value');

        $this->assertDatabaseHas('payments', [
            'farm_id' => $farm->id,
            'phone' => '254746933820',
            'status' => 'failed',
        ]);
    }

    public function test_successful_callback_activates_the_plan_and_is_idempotent(): void
    {
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/stkpushquery/*' => Http::response([
                'ResponseCode' => '0',
                'CheckoutRequestID' => 'checkout-2',
                'ResultCode' => '0',
            ]),
        ]);
        config(['services.mpesa' => [
            'environment' => 'sandbox', 'consumer_key' => 'key', 'consumer_secret' => 'secret',
            'shortcode' => '174379', 'passkey' => 'passkey',
            'callback_secret' => 'test-callback-secret-12345678901234567890',
        ]]);
        $user = User::factory()->create(['role' => 'farmOwner', 'phone' => '254712345678']);
        $farm = Farm::create(['name' => 'Paid Farm', 'mother_pig_count' => 10]);
        $payment = Payment::create([
            'farm_id' => $farm->id, 'user_id' => $user->id, 'plan_code' => 'starter',
            'mother_pig_count' => 10, 'amount' => 100, 'currency' => 'KES',
            'phone' => $user->phone, 'status' => 'pending',
            'checkout_request_id' => 'checkout-2',
        ]);

        $payload = ['Body' => ['stkCallback' => [
            'CheckoutRequestID' => 'checkout-2', 'ResultCode' => 0,
            'ResultDesc' => 'The service request is processed successfully.',
            'CallbackMetadata' => ['Item' => [
                ['Name' => 'Amount', 'Value' => 100],
                ['Name' => 'MpesaReceiptNumber', 'Value' => 'ABC123'],
            ]],
        ]]];

        $callbackUrl = '/api/v1/payments/mpesa/callback?callback_token=test-callback-secret-12345678901234567890';
        $this->postJson($callbackUrl, $payload)->assertOk();
        $this->postJson($callbackUrl, $payload)->assertOk();

        $this->assertDatabaseHas('payments', ['id' => $payment->id, 'status' => 'paid', 'mpesa_receipt' => 'ABC123']);
        $this->assertDatabaseHas('farms', ['id' => $farm->id, 'subscription_plan' => 'starter']);
    }

    public function test_unverified_success_callback_does_not_mark_payment_as_paid(): void
    {
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/stkpushquery/*' => Http::response([
                'ResponseCode' => '0',
                'CheckoutRequestID' => 'checkout-forged',
                'ResultCode' => '1032',
            ]),
        ]);
        config(['services.mpesa' => [
            'environment' => 'sandbox', 'consumer_key' => 'key', 'consumer_secret' => 'secret',
            'shortcode' => '174379', 'passkey' => 'passkey',
            'callback_secret' => 'test-callback-secret-12345678901234567890',
        ]]);
        $user = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Unverified Farm']);
        $payment = Payment::create([
            'farm_id' => $farm->id, 'user_id' => $user->id, 'plan_code' => 'starter',
            'mother_pig_count' => 10, 'amount' => 100, 'currency' => 'KES',
            'phone' => '254712345678', 'status' => 'pending',
            'checkout_request_id' => 'checkout-forged',
        ]);

        $callbackUrl = '/api/v1/payments/mpesa/callback?callback_token=test-callback-secret-12345678901234567890';
        $this->postJson($callbackUrl, ['Body' => ['stkCallback' => [
            'CheckoutRequestID' => 'checkout-forged',
            'ResultCode' => 0,
            'CallbackMetadata' => ['Item' => [
                ['Name' => 'Amount', 'Value' => 100],
                ['Name' => 'MpesaReceiptNumber', 'Value' => 'FAKE123'],
            ]],
        ]]])->assertUnprocessable();

        $this->assertDatabaseHas('payments', ['id' => $payment->id, 'status' => 'pending']);
        $this->assertDatabaseHas('farms', ['id' => $farm->id, 'subscription_plan' => null]);
    }

    public function test_callback_amount_must_match_the_paid_payment(): void
    {
        Http::fake([
            'sandbox.safaricom.co.ke/oauth/*' => Http::response(['access_token' => 'access-token']),
            'sandbox.safaricom.co.ke/mpesa/stkpushquery/*' => Http::response([
                'ResponseCode' => '0',
                'CheckoutRequestID' => 'checkout-mismatch',
                'ResultCode' => '0',
            ]),
        ]);
        config(['services.mpesa' => [
            'environment' => 'sandbox', 'consumer_key' => 'key', 'consumer_secret' => 'secret',
            'shortcode' => '174379', 'passkey' => 'passkey',
            'callback_secret' => 'test-callback-secret-12345678901234567890',
        ]]);
        $user = User::factory()->create(['role' => 'farmOwner']);
        $farm = Farm::create(['name' => 'Mismatched Amount Farm']);
        $payment = Payment::create([
            'farm_id' => $farm->id, 'user_id' => $user->id, 'plan_code' => 'starter',
            'mother_pig_count' => 10, 'amount' => 100, 'currency' => 'KES',
            'phone' => '254712345678', 'status' => 'pending',
            'checkout_request_id' => 'checkout-mismatch',
        ]);

        $callbackUrl = '/api/v1/payments/mpesa/callback?callback_token=test-callback-secret-12345678901234567890';
        $this->postJson($callbackUrl, ['Body' => ['stkCallback' => [
            'CheckoutRequestID' => 'checkout-mismatch',
            'ResultCode' => 0,
            'CallbackMetadata' => ['Item' => [
                ['Name' => 'Amount', 'Value' => 1],
                ['Name' => 'MpesaReceiptNumber', 'Value' => 'ABC123'],
            ]],
        ]]])->assertUnprocessable();

        $this->assertDatabaseHas('payments', ['id' => $payment->id, 'status' => 'pending']);
        $this->assertDatabaseHas('farms', ['id' => $farm->id, 'subscription_plan' => null]);
    }
}
