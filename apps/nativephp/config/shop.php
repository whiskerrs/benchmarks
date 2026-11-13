<?php

return [
    /*
    | Storefront GraphQL endpoint. On iOS the SHOP_API_URL process environment
    | variable is read at launch and wins over this value (see
    | App\Shop\Storefront::endpoint()). On Android set SHOP_API_URL in .env
    | before building.
    */
    'default_endpoint' => 'https://apparel-large-catalog.mock.shop/api',

    'endpoint' => env('SHOP_API_URL'),
];
