<?php

return [

    'paths' => ['api/*'],

    'allowed_methods' => ['*'],

    'allowed_origins' => array_filter(explode(',', env('CORS_ALLOWED_ORIGINS', ''))),

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    // Bearer-token API, not cookie/session based, so credentials are never needed cross-origin.
    'supports_credentials' => false,

];
