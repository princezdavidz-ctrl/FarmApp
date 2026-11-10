<?php

namespace App\Services\Auth;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;

/** Verifies Firebase ID tokens using Firebase's published signing certificates. */
class FirebaseIdTokenVerifier
{
    private const CERTIFICATES_URL = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

    /** @return array<string, mixed> */
    public function verify(string $token): array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            $this->invalid();
        }

        [$encodedHeader, $encodedPayload, $encodedSignature] = $parts;
        $header = $this->decodeJson($encodedHeader);
        $claims = $this->decodeJson($encodedPayload);
        $kid = $header['kid'] ?? null;
        if (($header['alg'] ?? null) !== 'RS256' || ! is_string($kid) || $kid === '') {
            $this->invalid();
        }

        $certificates = Cache::remember('firebase.auth.certificates', now()->addHours(5), fn () => Http::acceptJson()
            ->get(self::CERTIFICATES_URL)
            ->throw()
            ->json());
        $certificate = is_array($certificates) ? ($certificates[$kid] ?? null) : null;
        $signature = $this->decodeBase64Url($encodedSignature);
        if (! is_string($certificate) || $signature === false || openssl_verify(
            $encodedHeader.'.'.$encodedPayload,
            $signature,
            $certificate,
            OPENSSL_ALGO_SHA256,
        ) !== 1) {
            $this->invalid();
        }

        $projectId = (string) config('services.firebase.project_id');
        $now = time();
        if (($claims['aud'] ?? null) !== $projectId
            || ($claims['iss'] ?? null) !== "https://securetoken.google.com/{$projectId}"
            || ! is_string($claims['sub'] ?? null)
            || $claims['sub'] === ''
            || ! is_numeric($claims['exp'] ?? null)
            || (int) $claims['exp'] < $now
            || ! is_numeric($claims['iat'] ?? null)
            || (int) $claims['iat'] > $now + 60) {
            $this->invalid();
        }

        return $claims;
    }

    /** @return array<string, mixed> */
    private function decodeJson(string $value): array
    {
        $decoded = $this->decodeBase64Url($value);
        $json = is_string($decoded) ? json_decode($decoded, true) : null;
        if (! is_array($json)) {
            $this->invalid();
        }

        return $json;
    }

    private function decodeBase64Url(string $value): string|false
    {
        $value .= str_repeat('=', (4 - strlen($value) % 4) % 4);

        return base64_decode(strtr($value, '-_', '+/'), true);
    }

    private function invalid(): never
    {
        throw ValidationException::withMessages([
            'id_token' => ['The federated sign-in token is invalid or has expired.'],
        ]);
    }
}
