<?php

namespace Tests\Feature;

use App\Models\FarmNotification;
use App\Models\PushDevice;
use App\Models\User;
use App\Services\Notifications\FirebasePushService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class FirebasePushServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_sends_a_notification_payload_to_the_recipient_device(): void
    {
        $user = User::factory()->create();
        PushDevice::create([
            'user_id' => $user->id,
            'token' => 'device-token',
            'token_hash' => hash('sha256', 'device-token'),
            'platform' => 'android',
        ]);

        $privateKey = openssl_pkey_new([
            'private_key_type' => OPENSSL_KEYTYPE_RSA,
            'private_key_bits' => 2048,
        ]);
        $this->assertNotFalse($privateKey);
        $this->assertTrue(openssl_pkey_export($privateKey, $privateKeyPem));

        $credentialsPath = tempnam(sys_get_temp_dir(), 'firebase-service-account-');
        $this->assertNotFalse($credentialsPath);
        file_put_contents($credentialsPath, json_encode([
            'project_id' => 'your-firebase-project',
            'client_email' => 'firebase@example.iam.gserviceaccount.com',
            'private_key' => $privateKeyPem,
        ], JSON_THROW_ON_ERROR));
        config([
            'services.firebase.project_id' => 'your-firebase-project',
            'services.firebase.credentials' => $credentialsPath,
        ]);
        Cache::forget('firebase.fcm.access_token.'.hash(
            'sha256',
            'firebase@example.iam.gserviceaccount.com',
        ));
        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response([
                'access_token' => 'test-access-token',
                'expires_in' => 3600,
            ]),
            'https://fcm.googleapis.com/v1/projects/your-firebase-project/messages:send' => Http::response([
                'name' => 'projects/your-firebase-project/messages/1',
            ]),
        ]);

        $notification = new FarmNotification([
            'recipient_id' => $user->id,
            'title' => 'Farm alert',
            'body' => 'A new farm notification.',
            'action_route' => '/support',
        ]);
        $notification->id = 17;

        try {
            app(FirebasePushService::class)->send($notification);
        } finally {
            unlink($credentialsPath);
        }

        Http::assertSent(fn (Request $request): bool => str_ends_with($request->url(), '/messages:send')
            && $request->hasHeader('Authorization', 'Bearer test-access-token')
            && $request->data()['message']['token'] === 'device-token'
            && $request->data()['message']['notification']['title'] === 'Farm alert'
            && $request->data()['message']['android']['notification']['sound'] === 'default'
            && $request->data()['message']['data']['notification_id'] === '17'
            && $request->data()['message']['data']['action_route'] === '/support');
    }
}
