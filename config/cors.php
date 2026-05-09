<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS) Configuration
    |--------------------------------------------------------------------------
    |
    | Origins dibaca dari environment variable CORS_ALLOWED_ORIGINS
    | (comma separated). CORS_ALLOWED_ORIGINS_PATTERNS bersifat opsional
    | dan juga comma separated (regex pattern tanpa delimiter).
    |
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => array_values(array_filter(array_map('trim', explode(
        ',',
        env(
            'CORS_ALLOWED_ORIGINS',
            'http://localhost:5173,http://localhost:5174,http://127.0.0.1:5173,http://127.0.0.1:5174'
        )
    )))),

    'allowed_origins_patterns' => array_values(array_filter(array_map('trim', explode(
        ',',
        env('CORS_ALLOWED_ORIGINS_PATTERNS', '')
    )))) ,

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => true,

];
