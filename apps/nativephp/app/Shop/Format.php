<?php

namespace App\Shop;

/**
 * Turns Storefront API payloads into the flat arrays the views render.
 */
class Format
{
    /** `{amount: "75.0"}` → `$75.00`. All prices are USD. */
    public static function money(?array $money): string
    {
        return '$'.number_format((float) ($money['amount'] ?? 0), 2, '.', '');
    }

    /** Append the `width` query parameter to an API image URL. */
    public static function image(?string $url, int $width): ?string
    {
        if ($url === null || $url === '') {
            return null;
        }

        return $url.(str_contains($url, '?') ? '&' : '?').'width='.$width;
    }

    /**
     * A ProductCard fragment → card data.
     *
     * @return array{handle: string, title: string, image: ?string, thumb: ?string, price: string, compare: ?string}
     */
    public static function card(array $node): array
    {
        $price = $node['priceRange']['minVariantPrice'] ?? null;
        $compare = $node['compareAtPriceRange']['minVariantPrice'] ?? null;
        $onSale = $compare !== null && (float) $compare['amount'] > (float) ($price['amount'] ?? 0);
        $image = $node['featuredImage']['url'] ?? null;

        return [
            'handle' => (string) ($node['handle'] ?? ''),
            'title' => (string) ($node['title'] ?? ''),
            'image' => self::image($image, 480),
            'thumb' => self::image($image, 240),
            'price' => self::money($price),
            'compare' => $onSale ? self::money($compare) : null,
        ];
    }

    /** @return list<array> */
    public static function cards(array $nodes): array
    {
        return array_values(array_map([self::class, 'card'], array_filter($nodes, 'is_array')));
    }

    /**
     * A CartFields fragment → cart data.
     */
    public static function cart(?array $cart): ?array
    {
        if ($cart === null) {
            return null;
        }

        $lines = [];
        foreach ($cart['lines']['nodes'] ?? [] as $line) {
            $merchandise = $line['merchandise'] ?? [];
            $image = $merchandise['image']['url'] ?? ($merchandise['product']['featuredImage']['url'] ?? null);
            $variantTitle = (string) ($merchandise['title'] ?? '');
            $lines[] = [
                'id' => (string) $line['id'],
                'quantity' => (int) $line['quantity'],
                'total' => self::money($line['cost']['totalAmount'] ?? null),
                'title' => (string) ($merchandise['product']['title'] ?? ''),
                'variant' => $variantTitle === 'Default Title' ? '' : $variantTitle,
                'image' => self::image($image, 240),
            ];
        }

        return [
            'id' => (string) $cart['id'],
            'checkoutUrl' => (string) ($cart['checkoutUrl'] ?? ''),
            'totalQuantity' => (int) ($cart['totalQuantity'] ?? 0),
            'subtotal' => self::money($cart['cost']['subtotalAmount'] ?? null),
            'lines' => $lines,
        ];
    }
}
