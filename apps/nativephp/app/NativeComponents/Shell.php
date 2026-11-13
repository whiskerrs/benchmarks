<?php

namespace App\NativeComponents;

use App\Shop\Format;
use App\Shop\Storefront;
use Illuminate\View\View;
use Native\Mobile\AsyncTask;
use Native\Mobile\Attributes\Lazy;
use Native\Mobile\Edge\NativeComponent;
use Native\Mobile\Facades\Browser;
use Native\Mobile\Facades\Dialog;
use Shopbench\Native\PlatformLog;
use Throwable;

/**
 * The whole Everbloom app is one native screen.
 *
 * NativePHP's router keeps a single navigation stack, and its native tab bar
 * rebuilds a tab's screens when you switch back to it. The spec wants three
 * tabs that each keep their own stack, so this screen holds the three stacks
 * itself and renders the screen on top of the active one, plus a tab bar
 * drawn with EDGE elements (which also carries the accessibility identifiers
 * the benchmark needs).
 *
 * Each pushed screen is a plain state array in $screens, keyed by id. Network
 * requests run on NativePHP's background PHP lane (AsyncTask); responses are
 * applied only if the screen still exists and the request is still the
 * latest one for it.
 */
#[Lazy]
class Shell extends NativeComponent
{
    private const PAGE_SIZE = 24;

    private const SORTS = [
        'featured' => ['COLLECTION_DEFAULT', false],
        'best-selling' => ['BEST_SELLING', false],
        'price-asc' => ['PRICE', false],
        'price-desc' => ['PRICE', true],
    ];

    /** Active tab: home | search | cart. */
    public string $tab = 'home';

    /** @var array<string, list<string>> tab => screen ids, bottom to top */
    public array $stacks = [
        'home' => ['home'],
        'search' => ['search'],
        'cart' => ['cart'],
    ];

    /** @var array<string, array> screen id => screen state */
    public array $screens = [];

    public int $seq = 0;

    /** The in-memory cart (Format::cart()), null before the first add. */
    public ?array $cart = null;

    public bool $cartBusy = false;

    /** Bound to the search field (debounced 300 ms natively). */
    public string $searchQuery = '';

    private static bool $homeReadyLogged = false;

    /**
     * Shell is #[Lazy]: NativePHP publishes this placeholder (the Home
     * skeleton with the tab bar) before mount() runs, so the first frame
     * never waits for the network.
     */
    protected function placeholder(): View
    {
        $this->initState();

        return $this->render();
    }

    /**
     * The first Home request runs inline, right after the skeleton has been
     * painted: NativePHP's background lane for async tasks only comes up a
     * few seconds after launch, and waiting for it would hold Home back.
     * Everything later (retries included) runs on the background lane.
     */
    public function mount(): void
    {
        if ($this->screens === []) {
            $this->initState();
        }

        $req = ++$this->screens['home']['req'];
        try {
            $data = Storefront::send(Storefront::endpoint(), 'Home', Storefront::document('Home'), []);
        } catch (Throwable) {
            $this->screens['home']['status'] = 'error';

            return;
        }
        $this->applyHome($req, $data);
    }

    private function initState(): void
    {
        $this->screens = [
            'home' => ['type' => 'home', 'status' => 'loading', 'req' => 0, 'collections' => [], 'products' => []],
            'search' => [
                'type' => 'search', 'status' => 'idle', 'req' => 0, 'query' => '', 'anchor' => -1,
                'results' => [], 'total' => 0, 'cursor' => null, 'hasNext' => false, 'loadingMore' => false,
            ],
            'cart' => ['type' => 'cart'],
        ];
    }

    // ── Navigation ──────────────────────────────────────────────

    public function selectTab(string $tab): void
    {
        if (isset($this->stacks[$tab])) {
            $this->tab = $tab;
        }
    }

    public function goBack(): void
    {
        if (count($this->stacks[$this->tab]) <= 1) {
            return;
        }

        $id = array_pop($this->stacks[$this->tab]);
        unset($this->screens[$id]);
    }

    public function onBackPressed(): void
    {
        if (count($this->stacks[$this->tab]) > 1) {
            $this->goBack();

            return;
        }

        $this->back();
    }

    private function push(array $screen): string
    {
        $id = 'p'.(++$this->seq);
        $this->screens[$id] = $screen;
        $this->stacks[$this->tab][] = $id;

        return $id;
    }

    // ── Home ────────────────────────────────────────────────────

    public function loadHome(): void
    {
        $this->screens['home']['status'] = 'loading';
        $req = ++$this->screens['home']['req'];

        $this->request('Home', [], function (array $data) use ($req) {
            $this->applyHome($req, $data);
        }, function () use ($req) {
            if (($this->screens['home']['req'] ?? null) === $req) {
                $this->screens['home']['status'] = 'error';
            }
        });
    }

    private function applyHome(int $req, array $data): void
    {
        if (($this->screens['home']['req'] ?? null) !== $req) {
            return;
        }

        $collections = [];
        foreach ($data['collections']['nodes'] ?? [] as $node) {
            $url = $node['image']['url'] ?? null;
            $collections[] = [
                'handle' => (string) $node['handle'],
                'title' => (string) $node['title'],
                'image' => Format::image($url, 480),
                'banner' => Format::image($url, 1080),
            ];
        }

        $this->screens['home']['collections'] = $collections;
        $this->screens['home']['products'] = Format::cards($data['products']['nodes'] ?? []);
        $this->screens['home']['status'] = 'loaded';
    }

    // ── Collection ──────────────────────────────────────────────

    public function openCollection(string $handle): void
    {
        $title = '';
        foreach ($this->screens['home']['collections'] as $collection) {
            if ($collection['handle'] === $handle) {
                $title = $collection['title'];
                break;
            }
        }

        $id = $this->push([
            'type' => 'collection', 'handle' => $handle, 'title' => $title, 'description' => '',
            'sort' => 'featured', 'status' => 'loading', 'req' => 0,
            'products' => [], 'cursor' => null, 'hasNext' => false, 'loadingMore' => false,
        ]);

        $this->loadCollection($id);
    }

    public function setSort(string $id, string $sort): void
    {
        if (! isset($this->screens[$id], self::SORTS[$sort]) || $this->screens[$id]['sort'] === $sort) {
            return;
        }

        $this->screens[$id]['sort'] = $sort;
        $this->loadCollection($id);
    }

    public function retryCollection(string $id): void
    {
        if (isset($this->screens[$id])) {
            $this->loadCollection($id);
        }
    }

    public function loadMoreProducts(string $id): void
    {
        $screen = $this->screens[$id] ?? null;
        if ($screen === null || $screen['status'] !== 'loaded' || ! $screen['hasNext'] || $screen['loadingMore']) {
            return;
        }

        $this->loadCollection($id, more: true);
    }

    private function loadCollection(string $id, bool $more = false): void
    {
        $screen = &$this->screens[$id];

        if ($more) {
            $screen['loadingMore'] = true;
        } else {
            $screen['status'] = 'loading';
            $screen['products'] = [];
            $screen['cursor'] = null;
            $screen['hasNext'] = false;
            $screen['loadingMore'] = false;
            $screen['anchor'] = -1;
        }

        $req = ++$screen['req'];
        [$sortKey, $reverse] = self::SORTS[$screen['sort']];
        $variables = [
            'handle' => $screen['handle'],
            'first' => self::PAGE_SIZE,
            'sortKey' => $sortKey,
            'reverse' => $reverse,
        ];
        if ($more) {
            $variables['after'] = $screen['cursor'];
        }
        unset($screen);

        $this->request('CollectionProducts', $variables, function (array $data) use ($id, $req, $more) {
            if (($this->screens[$id]['req'] ?? null) !== $req) {
                return;
            }

            $collection = $data['collection'] ?? null;
            if (! is_array($collection)) {
                $this->screens[$id]['loadingMore'] = false;
                if (! $more) {
                    $this->screens[$id]['status'] = 'error';
                }

                return;
            }

            $page = $collection['products'] ?? [];
            $screen = &$this->screens[$id];
            $screen['title'] = (string) ($collection['title'] ?? $screen['title']);
            $screen['description'] = (string) ($collection['description'] ?? '');
            $screen['products'] = array_merge($screen['products'], Format::cards($page['nodes'] ?? []));
            $screen['cursor'] = $page['pageInfo']['endCursor'] ?? null;
            $screen['hasNext'] = (bool) ($page['pageInfo']['hasNextPage'] ?? false);
            $screen['loadingMore'] = false;
            $screen['status'] = 'loaded';
        }, function () use ($id, $req, $more) {
            if (($this->screens[$id]['req'] ?? null) !== $req) {
                return;
            }

            $this->screens[$id]['loadingMore'] = false;
            if (! $more) {
                $this->screens[$id]['status'] = 'error';
            }
        });
    }

    // ── Product ─────────────────────────────────────────────────

    /**
     * Open a product. $row is the list row it was tapped in (collection grid
     * row or search result), remembered so going back scrolls that row into
     * view again: only the top screen is rendered, so a list below is rebuilt
     * from its state when it comes back.
     */
    public function openProduct(string $handle, ?int $row = null): void
    {
        if ($row !== null) {
            $stack = $this->stacks[$this->tab];
            $below = $stack[count($stack) - 1];
            $this->screens[$below]['anchor'] = $row;
        }

        $id = $this->push([
            'type' => 'product', 'handle' => $handle, 'status' => 'loading', 'req' => 0,
            'product' => null, 'recs' => [], 'variant' => null, 'image' => 0, 'adding' => false,
        ]);

        $this->loadProduct($id);
    }

    public function retryProduct(string $id): void
    {
        if (isset($this->screens[$id])) {
            $this->loadProduct($id);
        }
    }

    private function loadProduct(string $id): void
    {
        $this->screens[$id]['status'] = 'loading';
        $req = ++$this->screens[$id]['req'];

        $this->request('Product', ['handle' => $this->screens[$id]['handle']], function (array $data) use ($id, $req) {
            if (($this->screens[$id]['req'] ?? null) !== $req) {
                return;
            }

            $product = $data['product'] ?? null;
            if (! is_array($product)) {
                $this->screens[$id]['status'] = 'error';

                return;
            }

            $variants = [];
            foreach ($product['variants']['nodes'] ?? [] as $node) {
                $options = [];
                foreach ($node['selectedOptions'] ?? [] as $option) {
                    $options[$option['name']] = $option['value'];
                }
                $onSale = isset($node['compareAtPrice']['amount'])
                    && (float) $node['compareAtPrice']['amount'] > (float) ($node['price']['amount'] ?? 0);
                $variants[] = [
                    'id' => (string) $node['id'],
                    'available' => (bool) ($node['availableForSale'] ?? false),
                    'options' => $options,
                    'price' => Format::money($node['price'] ?? null),
                    'compare' => $onSale ? Format::money($node['compareAtPrice']) : null,
                ];
            }

            $options = [];
            foreach ($product['options'] ?? [] as $option) {
                $values = array_map(fn ($v) => (string) $v['name'], $option['optionValues'] ?? []);
                if ($option['name'] === 'Title' && $values === ['Default Title']) {
                    continue;
                }
                $options[] = ['name' => (string) $option['name'], 'values' => $values];
            }

            $selected = null;
            foreach ($variants as $index => $variant) {
                if ($variant['available']) {
                    $selected = $index;
                    break;
                }
            }

            $images = [];
            foreach (array_slice($product['images']['nodes'] ?? [], 0, 10) as $image) {
                $images[] = Format::image($image['url'] ?? null, 1080);
            }

            $screen = &$this->screens[$id];
            $screen['product'] = [
                'title' => (string) $product['title'],
                'description' => (string) ($product['description'] ?? ''),
                'images' => $images,
                'options' => $options,
                'variants' => $variants,
            ];
            $screen['variant'] = $variants === [] ? null : ($selected ?? 0);
            $screen['recs'] = Format::cards($data['productRecommendations'] ?? []);
            $screen['image'] = 0;
            $screen['status'] = 'loaded';
        }, function () use ($id, $req) {
            if (($this->screens[$id]['req'] ?? null) === $req) {
                $this->screens[$id]['status'] = 'error';
            }
        });
    }

    public function showImage(string $id, int $index): void
    {
        if (isset($this->screens[$id])) {
            $this->screens[$id]['image'] = $index;
        }
    }

    public function selectOption(string $id, int $optionIndex, int $valueIndex): void
    {
        $product = $this->screens[$id]['product'] ?? null;
        $option = $product['options'][$optionIndex] ?? null;
        $value = $option['values'][$valueIndex] ?? null;
        if ($option === null || $value === null) {
            return;
        }

        $current = $product['variants'][$this->screens[$id]['variant']]['options'] ?? [];
        $wanted = array_merge($current, [$option['name'] => $value]);

        $match = null;
        foreach ($product['variants'] as $index => $variant) {
            if ($variant['options'] == $wanted) {
                $match = $index;
                break;
            }
        }
        if ($match === null) {
            foreach ($product['variants'] as $index => $variant) {
                if (($variant['options'][$option['name']] ?? null) === $value) {
                    $match = $index;
                    break;
                }
            }
        }

        if ($match !== null) {
            $this->screens[$id]['variant'] = $match;
        }
    }

    public function addToCart(string $id): void
    {
        $screen = $this->screens[$id] ?? null;
        $variant = $screen['product']['variants'][$screen['variant'] ?? -1] ?? null;
        if ($variant === null || $screen['adding'] || $this->cartBusy) {
            return;
        }

        $this->screens[$id]['adding'] = true;
        $this->cartBusy = true;
        $lines = [['merchandiseId' => $variant['id'], 'quantity' => 1]];

        [$operation, $variables, $key] = $this->cart === null
            ? ['CartCreate', ['lines' => $lines], 'cartCreate']
            : ['CartLinesAdd', ['cartId' => $this->cart['id'], 'lines' => $lines], 'cartLinesAdd'];

        $this->request($operation, $variables, function (array $data) use ($id, $key) {
            $this->cartBusy = false;
            if (isset($this->screens[$id])) {
                $this->screens[$id]['adding'] = false;
            }
            if ($this->applyCartPayload($data[$key] ?? null)) {
                $this->tab = 'cart';
            }
        }, function () use ($id) {
            $this->cartBusy = false;
            if (isset($this->screens[$id])) {
                $this->screens[$id]['adding'] = false;
            }
            Dialog::alert('Couldn’t add to cart', 'Check your connection and try again.', ['OK']);
        });
    }

    // ── Cart ────────────────────────────────────────────────────

    public function changeQuantity(int $index, int $delta): void
    {
        $line = $this->cart['lines'][$index] ?? null;
        if ($line === null || $this->cartBusy) {
            return;
        }

        $this->cartBusy = true;
        $variables = [
            'cartId' => $this->cart['id'],
            'lines' => [['id' => $line['id'], 'quantity' => max(0, $line['quantity'] + $delta)]],
        ];

        $this->request('CartLinesUpdate', $variables, function (array $data) {
            $this->cartBusy = false;
            $this->applyCartPayload($data['cartLinesUpdate'] ?? null);
        }, function () {
            $this->cartBusy = false;
            Dialog::alert('Couldn’t update cart', 'Check your connection and try again.', ['OK']);
        });
    }

    public function checkout(): void
    {
        if (! empty($this->cart['checkoutUrl'])) {
            Browser::inApp($this->cart['checkoutUrl']);
        }
    }

    /**
     * Replace the cart with the one in a cart mutation payload and surface the
     * first user error. Returns true when the payload carried no user errors.
     */
    private function applyCartPayload(?array $payload): bool
    {
        if ($payload === null) {
            return false;
        }

        if (isset($payload['cart']) && is_array($payload['cart'])) {
            $this->cart = Format::cart($payload['cart']);
        }

        $errors = $payload['userErrors'] ?? [];
        if ($errors !== []) {
            Dialog::alert('Cart', (string) ($errors[0]['message'] ?? 'Something went wrong.'), ['OK']);

            return false;
        }

        return true;
    }

    // ── Search ──────────────────────────────────────────────────

    public function updatedSearchQuery(): void
    {
        if (trim($this->searchQuery) !== $this->screens['search']['query'] || $this->screens['search']['status'] === 'error') {
            $this->search();
        }
    }

    public function retrySearch(): void
    {
        $this->search();
    }

    public function loadMoreResults(): void
    {
        $screen = $this->screens['search'];
        if ($screen['status'] !== 'loaded' || ! $screen['hasNext'] || $screen['loadingMore']) {
            return;
        }

        $this->search(more: true);
    }

    private function search(bool $more = false): void
    {
        $screen = &$this->screens['search'];
        $req = ++$screen['req'];

        if ($more) {
            $query = $screen['query'];
            $screen['loadingMore'] = true;
        } else {
            $query = trim($this->searchQuery);
            $screen['query'] = $query;
            $screen['results'] = [];
            $screen['total'] = 0;
            $screen['cursor'] = null;
            $screen['hasNext'] = false;
            $screen['loadingMore'] = false;
            $screen['anchor'] = -1;
            $screen['status'] = $query === '' ? 'idle' : 'loading';
        }

        $variables = ['query' => $query, 'first' => self::PAGE_SIZE];
        if ($more) {
            $variables['after'] = $screen['cursor'];
        }
        unset($screen);

        if ($query === '') {
            return;
        }

        $current = fn () => ($this->screens['search']['req'] ?? null) === $req
            && $this->screens['search']['query'] === $query;

        $this->request('Search', $variables, function (array $data) use ($current) {
            if (! $current()) {
                return; // a response for a query that is no longer the current one
            }

            $search = $data['search'] ?? [];
            $screen = &$this->screens['search'];
            $screen['results'] = array_merge($screen['results'], Format::cards($search['nodes'] ?? []));
            $screen['total'] = (int) ($search['totalCount'] ?? 0);
            $screen['cursor'] = $search['pageInfo']['endCursor'] ?? null;
            $screen['hasNext'] = (bool) ($search['pageInfo']['hasNextPage'] ?? false);
            $screen['loadingMore'] = false;
            $screen['status'] = 'loaded';
        }, function () use ($current, $more) {
            if (! $current()) {
                return;
            }

            $this->screens['search']['loadingMore'] = false;
            if (! $more) {
                $this->screens['search']['status'] = 'error';
            }
        });
    }

    // ── Networking ──────────────────────────────────────────────

    /**
     * Send a Storefront operation on the background PHP lane and hand the
     * `data` object (or the failure) back to this screen.
     *
     * NativePHP refuses async tasks until its background lane is up (Android:
     * ~2.5 s after launch). A refused request runs inline instead, so the
     * first Home load never fails just because it was early.
     */
    private function request(string $operation, array $variables, \Closure $done, \Closure $fail): void
    {
        $endpoint = Storefront::endpoint();
        $document = Storefront::document($operation);
        $work = static fn () => Storefront::send($endpoint, $operation, $document, $variables);

        AsyncTask::dispatch($work)
            ->timeout(45)
            ->finished(function ($data) use ($done) {
                $done(is_array($data) ? $data : []);
            })
            ->failed(function (Throwable $e) use ($work, $done, $fail) {
                if (str_contains($e->getMessage(), 'background lane is not available')) {
                    try {
                        $data = $work();
                    } catch (Throwable $inline) {
                        $fail($inline);

                        return;
                    }
                    $done($data);

                    return;
                }

                $fail($e);
            });
    }

    // ── Render ──────────────────────────────────────────────────

    public function render(): View
    {
        $stack = $this->stacks[$this->tab];
        $id = $stack[count($stack) - 1];
        $screen = $this->screens[$id];

        if (! self::$homeReadyLogged && $this->screens['home']['status'] === 'loaded' && $id === 'home') {
            self::$homeReadyLogged = true;
            PlatformLog::write('SHOPBENCH home_ready');
        }

        return view('native.shell', [
            'id' => $id,
            'screen' => $screen,
            'canGoBack' => count($stack) > 1,
            'cartCount' => $this->cart['totalQuantity'] ?? 0,
        ]);
    }
}
