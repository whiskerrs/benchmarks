<?php

namespace App\Shop;

use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Plain-HTTP client for the Shopify Storefront GraphQL API (mock.shop).
 *
 * Operations are taken verbatim from resources/graphql/storefront.graphql
 * (a copy of spec/storefront.graphql). Each request sends the operation plus
 * the fragments it uses, with `operationName` always set.
 */
class Storefront
{
    /** @var array<string, string>|null name => definition source */
    private static ?array $definitions = null;

    /** @var array<string, string> operation name => document */
    private static array $documents = [];

    private static ?string $endpoint = null;

    /**
     * The endpoint to talk to. iOS: SHOP_API_URL from the process environment
     * at launch (devicectl / simctl). Android: SHOP_API_URL baked into .env at
     * build time. Otherwise the default mock.shop endpoint.
     */
    public static function endpoint(): string
    {
        if (self::$endpoint !== null) {
            return self::$endpoint;
        }

        $fromProcess = getenv('SHOP_API_URL');
        if (is_string($fromProcess) && trim($fromProcess) !== '') {
            return self::$endpoint = trim($fromProcess);
        }

        $fromConfig = config('shop.endpoint');
        if (is_string($fromConfig) && trim($fromConfig) !== '') {
            return self::$endpoint = trim($fromConfig);
        }

        return self::$endpoint = config('shop.default_endpoint');
    }

    /**
     * The GraphQL document for one operation: the fragments it spreads
     * (transitively), followed by the operation itself, all as written.
     */
    public static function document(string $operation): string
    {
        if (isset(self::$documents[$operation])) {
            return self::$documents[$operation];
        }

        $defs = self::definitions();
        if (! isset($defs[$operation])) {
            throw new RuntimeException("Unknown operation {$operation}");
        }

        $needed = [];
        $queue = [$defs[$operation]];
        while ($queue) {
            $source = array_shift($queue);
            preg_match_all('/\.\.\.\s*([A-Za-z_][A-Za-z0-9_]*)/', $source, $m);
            foreach ($m[1] as $name) {
                if ($name === 'on' || isset($needed[$name]) || ! isset($defs[$name])) {
                    continue;
                }
                $needed[$name] = true;
                $queue[] = $defs[$name];
            }
        }

        $parts = [];
        foreach ($defs as $name => $source) {
            if (isset($needed[$name])) {
                $parts[] = $source;
            }
        }
        $parts[] = $defs[$operation];

        return self::$documents[$operation] = implode("\n\n", $parts);
    }

    /**
     * Run one operation. Executed inside an AsyncTask (background PHP
     * thread), so everything it needs is passed in.
     *
     * @return array<string, mixed> the `data` object
     */
    public static function send(string $endpoint, string $operation, string $document, array $variables): array
    {
        $response = Http::connectTimeout(8)
            ->timeout(20)
            ->acceptJson()
            ->withBody(json_encode([
                'operationName' => $operation,
                'query' => $document,
                'variables' => (object) $variables,
            ], JSON_UNESCAPED_SLASHES), 'application/json')
            ->post($endpoint);

        if (! $response->successful()) {
            throw new RuntimeException("{$operation} failed with HTTP {$response->status()}");
        }

        $json = $response->json();
        if (! is_array($json) || ! isset($json['data']) || ! is_array($json['data'])) {
            $message = $json['errors'][0]['message'] ?? 'Malformed response';
            throw new RuntimeException("{$operation} failed: {$message}");
        }

        return $json['data'];
    }

    /** @return array<string, string> */
    private static function definitions(): array
    {
        if (self::$definitions !== null) {
            return self::$definitions;
        }

        $source = file_get_contents(resource_path('graphql/storefront.graphql'));
        $defs = [];
        $length = strlen($source);
        $i = 0;
        while ($i < $length) {
            if (! preg_match('/(fragment|query|mutation)\s+([A-Za-z_][A-Za-z0-9_]*)/A', $source, $m, 0, $i)) {
                $i++;

                continue;
            }
            $start = $i;
            $open = strpos($source, '{', $i);
            $depth = 0;
            for ($j = $open; $j < $length; $j++) {
                if ($source[$j] === '{') {
                    $depth++;
                } elseif ($source[$j] === '}') {
                    $depth--;
                    if ($depth === 0) {
                        break;
                    }
                }
            }
            $defs[$m[2]] = substr($source, $start, $j - $start + 1);
            $i = $j + 1;
        }

        return self::$definitions = $defs;
    }
}
