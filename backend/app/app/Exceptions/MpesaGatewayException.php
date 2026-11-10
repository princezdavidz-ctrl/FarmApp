<?php

namespace App\Exceptions;

use RuntimeException;

class MpesaGatewayException extends RuntimeException
{
    public function __construct(
        public readonly string $stage,
        public readonly int $upstreamStatus,
        public readonly ?string $providerCode,
        public readonly ?string $requestId,
        public readonly string $providerMessage,
    ) {
        parent::__construct("Safaricom {$stage} request failed (HTTP {$upstreamStatus}).");
    }
}
