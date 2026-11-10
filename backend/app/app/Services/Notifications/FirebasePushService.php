<?php

namespace App\Services\Notifications;

use App\Models\FarmNotification;
use App\Models\PushDevice;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

class FirebasePushService
{
    public function send(FarmNotification $notification): void
    {
        $credentialPath = config('services.firebase.credentials');
        if (! is_string($credentialPath) || $credentialPath === '') {
            Log::warning('Firebase push is disabled because FIREBASE_CREDENTIALS is not configured.');

            return;
        }

        $userIds = $notification->recipient_id === null
            ? $notification->farm->users()->pluck('users.id')
            : collect([$notification->recipient_id]);
        $devices = PushDevice::query()->whereIn('user_id', $userIds)->get();
        if ($devices->isEmpty()) {
            return;
        }

        $credentials = $this->credentials($credentialPath);
        $projectId = config('services.firebase.project_id');
        if (! is_string($projectId) || $credentials['project_id'] !== $projectId) {
            throw new RuntimeException('Firebase service-account project does not match FIREBASE_PROJECT_ID.');
        }
        $accessToken = $this->accessToken($credentials);

        foreach ($devices as $device) {
            $response = Http::acceptJson()
                ->withToken($accessToken)
                ->timeout(15)
                ->post("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send", [
                    'message' => [
                        'token' => $device->token,
                        'notification' => [
                            'title' => $notification->title,
                            'body' => $notification->body,
                        ],
                        'data' => [
                            'notification_id' => (string) $notification->id,
                            'action_route' => (string) ($notification->action_route ?? '/notifications'),
                        ],
                        'android' => ['priority' => 'high'],
                        'apns' => [
                            'headers' => ['apns-priority' => '10'],
                            'payload' => ['aps' => ['sound' => 'default']],
                        ],
                    ],
                ]);

            if ($response->successful()) {
                continue;
            }

            $body = $response->json();
            $errorCode = is_array($body) ? data_get($body, 'error.details.0.errorCode') : null;
            if ($errorCode === 'UNREGISTERED') {
                $device->delete();

                continue;
            }

            Log::warning('Firebase push delivery failed.', [
                'notification_id' => $notification->id,
                'device_id' => $device->id,
                'status' => $response->status(),
                'response' => $response->body(),
            ]);
        }
    }

    /** @return array{project_id: string, client_email: string, private_key: string} */
    private function credentials(string $path): array
    {
        if (! is_file($path) || ! is_readable($path)) {
            throw new RuntimeException('Firebase service-account credentials are unavailable.');
        }

        $contents = file_get_contents($path);
        $credentials = $contents === false ? null : json_decode($contents, true);
        if (! is_array($credentials) ||
            ! is_string($credentials['project_id'] ?? null) ||
            ! is_string($credentials['client_email'] ?? null) ||
            ! is_string($credentials['private_key'] ?? null)) {
            throw new RuntimeException('Firebase service-account credentials are invalid.');
        }

        return $credentials;
    }

    /** @param array{project_id: string, client_email: string, private_key: string} $credentials */
    private function accessToken(array $credentials): string
    {
        $cacheKey = 'firebase.fcm.access_token.'.hash('sha256', $credentials['client_email']);

        return Cache::remember($cacheKey, now()->addMinutes(55), function () use ($credentials): string {
            $issuedAt = time();
            $jwt = $this->base64UrlEncode(json_encode([
                'alg' => 'RS256',
                'typ' => 'JWT',
            ], JSON_THROW_ON_ERROR)).'.'.$this->base64UrlEncode(json_encode([
                'iss' => $credentials['client_email'],
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $issuedAt,
                'exp' => $issuedAt + 3600,
            ], JSON_THROW_ON_ERROR));

            if (! openssl_sign($jwt, $signature, $credentials['private_key'], OPENSSL_ALGO_SHA256)) {
                throw new RuntimeException('Could not sign Firebase service-account credentials.');
            }

            $response = Http::asForm()->acceptJson()->timeout(15)->post(
                'https://oauth2.googleapis.com/token',
                [
                    'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                    'assertion' => $jwt.'.'.$this->base64UrlEncode($signature),
                ],
            );

            if (! $response->successful() || ! is_string($response->json('access_token'))) {
                throw new RuntimeException('Firebase did not issue a push access token.');
            }

            return $response->json('access_token');
        });
    }

    private function base64UrlEncode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
