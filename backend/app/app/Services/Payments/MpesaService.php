<?php

namespace App\Services\Payments;

use App\Exceptions\MpesaGatewayException;
use App\Models\DriverPayment;
use App\Models\Payment;
use App\Models\SupplierPayment;
use App\Models\VeterinaryPayment;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class MpesaService
{
    public function initiate(Payment|DriverPayment|SupplierPayment|VeterinaryPayment $payment): array
    {
        $environment = config('services.mpesa.environment');
        $baseUrl = $environment === 'production'
            ? 'https://api.safaricom.co.ke'
            : 'https://sandbox.safaricom.co.ke';
        $key = config('services.mpesa.consumer_key');
        $secret = config('services.mpesa.consumer_secret');
        $shortcode = trim((string) config('services.mpesa.shortcode', ''));
        $passkey = config('services.mpesa.passkey');
        $callbackUrl = config('services.mpesa.callback_url');
        $callbackSecret = config('services.mpesa.callback_secret');
        $transactionType = config('services.mpesa.transaction_type', 'CustomerPayBillOnline');

        if (! in_array($environment, ['sandbox', 'production'], true)) {
            throw new RuntimeException('M-Pesa environment must be sandbox or production.');
        }

        if (! $key || ! $secret || ! $shortcode || ! $passkey || ! $callbackUrl ||
            ! is_string($callbackSecret) || strlen($callbackSecret) < 32) {
            throw new RuntimeException('M-Pesa is not configured.');
        }

        if (! preg_match('/^\d+$/', $shortcode)) {
            throw new RuntimeException('M-Pesa business shortcode must contain digits only.');
        }

        if (! in_array($transactionType, ['CustomerPayBillOnline', 'CustomerBuyGoodsOnline'], true)) {
            throw new RuntimeException('M-Pesa transaction type must match the business shortcode.');
        }

        $this->validateCallbackUrl($callbackUrl);

        $tokenResponse = Http::asForm()->acceptJson()->timeout(30)->connectTimeout(15)
            ->withBasicAuth($key, $secret)
            ->get($baseUrl.'/oauth/v1/generate?grant_type=client_credentials');
        $this->throwIfProviderFailed($tokenResponse, 'OAuth');
        $accessToken = $tokenResponse->json('access_token');
        if (! is_string($accessToken) || blank($accessToken)) {
            throw new RuntimeException('M-Pesa did not return an access token.');
        }
        $timestamp = now()->format('YmdHis');

        $stkResponse = Http::acceptJson()->timeout(30)->connectTimeout(15)
            ->withToken($accessToken)->post($baseUrl.'/mpesa/stkpush/v1/processrequest', [
                'BusinessShortCode' => $shortcode,
                'Password' => base64_encode($shortcode.$passkey.$timestamp),
                'Timestamp' => $timestamp,
                'TransactionType' => $transactionType,
                'Amount' => (int) ceil((float) $payment->amount),
                'PartyA' => $payment->phone,
                'PartyB' => $shortcode,
                'PhoneNumber' => $payment->phone,
                'CallBackURL' => $this->callbackUrlWithSecret($callbackUrl, $callbackSecret),
                'AccountReference' => match (true) {
                    $payment instanceof VeterinaryPayment => 'Vet-'.$payment->veterinarian_profile_id,
                    $payment instanceof DriverPayment => 'Driver-'.$payment->driver_profile_id,
                    $payment instanceof SupplierPayment => 'Supplier-'.$payment->supplier_profile_id,
                    default => 'Farm-'.$payment->farm_id,
                },
                'TransactionDesc' => match (true) {
                    $payment instanceof VeterinaryPayment => 'FarmApp veterinary subscription',
                    $payment instanceof DriverPayment => 'FarmApp driver subscription',
                    $payment instanceof SupplierPayment => 'FarmApp animal supplier subscription',
                    default => 'FarmApp subscription',
                },
            ]);

        $this->throwIfProviderFailed($stkResponse, 'STK push');
        $response = $stkResponse->json();
        if (! is_array($response)) {
            throw new RuntimeException('M-Pesa returned an invalid STK response.');
        }

        if ((string) ($response['ResponseCode'] ?? '') !== '0') {
            throw new MpesaGatewayException(
                'STK push',
                $stkResponse->status(),
                $this->scalar($response['errorCode'] ?? $response['ResponseCode'] ?? null),
                $this->scalar($response['requestId'] ?? $response['RequestId'] ?? $response['MerchantRequestID'] ?? null),
                $this->scalar($response['errorMessage'] ?? $response['ResponseDescription'] ?? null)
                    ?? 'Safaricom rejected the STK request.',
            );
        }

        if (blank($response['MerchantRequestID'] ?? null) ||
            blank($response['CheckoutRequestID'] ?? null)) {
            throw new RuntimeException('M-Pesa accepted the request without returning request identifiers.');
        }

        return $response;
    }

    public function queryResultCode(Payment|DriverPayment|SupplierPayment|VeterinaryPayment $payment): int
    {
        $environment = config('services.mpesa.environment');
        $baseUrl = $environment === 'production'
            ? 'https://api.safaricom.co.ke'
            : 'https://sandbox.safaricom.co.ke';
        $key = config('services.mpesa.consumer_key');
        $secret = config('services.mpesa.consumer_secret');
        $shortcode = trim((string) config('services.mpesa.shortcode', ''));
        $passkey = config('services.mpesa.passkey');

        if (! in_array($environment, ['sandbox', 'production'], true) ||
            ! $key || ! $secret || ! $shortcode || ! $passkey ||
            blank($payment->checkout_request_id)) {
            throw new RuntimeException('M-Pesa transaction verification is not configured.');
        }

        $tokenResponse = Http::asForm()->acceptJson()->timeout(30)->connectTimeout(15)
            ->withBasicAuth($key, $secret)
            ->get($baseUrl.'/oauth/v1/generate?grant_type=client_credentials');
        $this->throwIfProviderFailed($tokenResponse, 'OAuth');
        $accessToken = $tokenResponse->json('access_token');
        if (! is_string($accessToken) || blank($accessToken)) {
            throw new RuntimeException('M-Pesa did not return an access token.');
        }

        $timestamp = now()->format('YmdHis');
        $queryResponse = Http::acceptJson()->timeout(30)->connectTimeout(15)
            ->withToken($accessToken)
            ->post($baseUrl.'/mpesa/stkpushquery/v1/query', [
                'BusinessShortCode' => $shortcode,
                'Password' => base64_encode($shortcode.$passkey.$timestamp),
                'Timestamp' => $timestamp,
                'CheckoutRequestID' => $payment->checkout_request_id,
            ]);
        $this->throwIfProviderFailed($queryResponse, 'STK query');

        if ((string) $queryResponse->json('ResponseCode') !== '0' ||
            $queryResponse->json('CheckoutRequestID') !== $payment->checkout_request_id) {
            throw new RuntimeException('M-Pesa could not verify the requested checkout transaction.');
        }

        $resultCode = $queryResponse->json('ResultCode');
        if (! is_numeric($resultCode)) {
            throw new RuntimeException('M-Pesa returned an invalid transaction verification response.');
        }

        return (int) $resultCode;
    }

    private function throwIfProviderFailed(Response $response, string $stage): void
    {
        if ($response->successful()) {
            return;
        }

        $body = $response->json();
        $body = is_array($body) ? $body : [];

        throw new MpesaGatewayException(
            $stage,
            $response->status(),
            $this->scalar($body['errorCode'] ?? $body['ResponseCode'] ?? null),
            $this->scalar($body['requestId'] ?? $body['RequestId'] ?? $body['MerchantRequestID'] ?? null),
            $this->scalar($body['errorMessage'] ?? $body['ResponseDescription'] ?? $body['message'] ?? null)
                ?? 'Safaricom returned an unsuccessful response.',
        );
    }

    private function scalar(mixed $value): ?string
    {
        return is_string($value) || is_numeric($value) ? (string) $value : null;
    }

    private function validateCallbackUrl(string $callbackUrl): void
    {
        $parts = parse_url($callbackUrl);
        $host = $parts['host'] ?? '';

        $isIpAddress = filter_var($host, FILTER_VALIDATE_IP) !== false;
        $isPublicIpAddress = filter_var(
            $host,
            FILTER_VALIDATE_IP,
            FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE,
        ) !== false;

        if (($parts['scheme'] ?? null) !== 'https' || ! $host ||
            in_array($host, ['localhost', 'example.test'], true) ||
            ($isIpAddress && ! $isPublicIpAddress)) {
            throw new RuntimeException('M-Pesa callback URL must be a publicly reachable HTTPS URL.');
        }
    }

    private function callbackUrlWithSecret(string $callbackUrl, string $secret): string
    {
        $parts = parse_url($callbackUrl);
        $query = [];
        parse_str($parts['query'] ?? '', $query);
        $query['callback_token'] = $secret;

        $baseUrl = $parts['scheme'].'://'.$parts['host'];
        if (isset($parts['port'])) {
            $baseUrl .= ':'.$parts['port'];
        }
        $baseUrl .= $parts['path'] ?? '';

        return $baseUrl.'?'.http_build_query($query);
    }
}
