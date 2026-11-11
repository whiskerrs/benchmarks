import type { Answer, Result, Sources } from './app.contract.d.ts';
import { CART_CREATE, CART_LINES_ADD, CART_LINES_UPDATE, COLLECTION_PRODUCTS, HOME, PRODUCT, SEARCH } from './graphql.ts';

// Any host: the default endpoint is https, the benchmark's replay server is
// plain http on a LAN address chosen at run time.
export const grants = 'net.fetch https:\nnet.fetch http:';

const DEFAULT_ENDPOINT = 'https://apparel-large-catalog.mock.shop/api';
const PAGE = 24;
// The build's SHOP_API_URL, if any (Android reads the endpoint only from here).
const BUILD_ENDPOINT = import.meta.env.SHOP_API_URL ?? '';

type Card = Result<'loadHome'>['best'][number];
type Cart = Result<'addToCart'>['cart'];
type Native = Parameters<Answer>[4];

// ---- endpoint -------------------------------------------------------------

/** SHOP_API_URL from the launch environment (iOS, through the native module),
 * else the build's setting (Android), else mock.shop. Only the `shopEndpoint`
 * mutation calls this: a resource that touched the native module would be
 * kept across launches. */
function endpointFor(native: Native): string {
  let url = '';
  if (native?.available) {
    try {
      const reply = native.call({ op: 'env' }) as { url?: string };
      url = typeof reply.url === 'string' ? reply.url : '';
    } catch {
      url = '';
    }
  }
  if (url === '') url = String(BUILD_ENDPOINT);
  return url.trim() !== '' ? url.trim() : DEFAULT_ENDPOINT;
}

type Gql = { data?: any; errors?: { message: string }[] };

async function gql(api: string, operationName: string, query: string, variables: Record<string, unknown>): Promise<any> {
  const response = await fetch(api, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ operationName, query, variables }),
    exactTimeout: 30000,
  } as RequestInit);
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const body = (await response.json()) as Gql;
  if (!body.data) throw new Error(body.errors?.[0]?.message ?? 'No data');
  return body.data;
}

// ---- formatting -----------------------------------------------------------

type Money = { amount: string; currencyCode: string } | null | undefined;

const money = (m: Money): string => `$${Number(m?.amount ?? 0).toFixed(2)}`;
const amount = (m: Money): number => Number(m?.amount ?? 0);

/** The API's image URL with `width` added, or "" for none. */
function sized(url: string | null | undefined, width: number): string {
  if (!url) return '';
  return `${url}${url.includes('?') ? '&' : '?'}width=${width}`;
}

function card(p: any, index: number, width: number): Card {
  const price = p.priceRange?.minVariantPrice;
  const compare = p.compareAtPriceRange?.minVariantPrice;
  return {
    id: p.id,
    handle: p.handle,
    title: p.title,
    image: sized(p.featuredImage?.url, width),
    price: money(price),
    compare: amount(compare) > amount(price) ? money(compare) : '',
    index,
  };
}

/** Two cards a row, for a virtualized grid. */
function rows(cards: Card[], key: string) {
  const out: { key: string; kind: string; cards: Card[] }[] = [];
  for (let i = 0; i < cards.length; i += 2) out.push({ key: `${key}:${cards[i].id}`, kind: 'cards', cards: cards.slice(i, i + 2) });
  return out;
}

// ---- Home -----------------------------------------------------------------

async function loadHome(api: string): Promise<Result<'loadHome'>> {
  if (api === '') return { loaded: false, collections: [], best: [] };
  const data = await gql(api, 'Home', HOME, {});
  return {
    loaded: true,
    collections: (data.collections?.nodes ?? []).map((c: any) => ({
      id: c.id,
      handle: c.handle,
      title: c.title,
      banner: sized(c.image?.url, 1080),
      image: sized(c.image?.url, 480),
    })),
    best: (data.products?.nodes ?? []).map((p: any, i: number) => card(p, i, 480)),
  };
}

// ---- Collection -----------------------------------------------------------

const SORTS: Record<string, { sortKey: string; reverse: boolean }> = {
  featured: { sortKey: 'COLLECTION_DEFAULT', reverse: false },
  'best-selling': { sortKey: 'BEST_SELLING', reverse: false },
  'price-asc': { sortKey: 'PRICE', reverse: false },
  'price-desc': { sortKey: 'PRICE', reverse: true },
};

type Paged = { title: string; description: string; total: number; cards: Card[]; cursor: string | null; hasNext: boolean; pages: number };
const collections = new Map<string, Paged>();

async function loadCollection(api: string, handle: string, sort: string, pages: number): Promise<Result<'loadCollection'>> {
  const key = `${handle}|${sort}`;
  if (handle === '' || api === '') return { key, loaded: false, title: '', description: '', hasNext: false, rows: [] };
  let paged = collections.get(key);
  if (!paged || paged.pages > pages) paged = { title: '', description: '', total: 0, cards: [], cursor: null, hasNext: true, pages: 0 };
  const { sortKey, reverse } = SORTS[sort] ?? SORTS.featured;
  while (paged.pages < pages && (paged.pages === 0 || paged.hasNext)) {
    const variables: Record<string, unknown> = { handle, first: PAGE, sortKey, reverse };
    if (paged.cursor) variables.after = paged.cursor;
    const data = await gql(api, 'CollectionProducts', COLLECTION_PRODUCTS, variables);
    const c = data.collection;
    if (!c) throw new Error('No such collection');
    const offset = paged.cards.length;
    paged = {
      title: c.title,
      description: c.description ?? '',
      total: 0,
      cards: paged.cards.concat((c.products?.nodes ?? []).map((p: any, i: number) => card(p, offset + i, 480))),
      cursor: c.products?.pageInfo?.endCursor ?? null,
      hasNext: Boolean(c.products?.pageInfo?.hasNextPage),
      pages: paged.pages + 1,
    };
    collections.set(key, paged);
  }
  return { key, loaded: true, title: paged.title, description: paged.description, hasNext: paged.hasNext, rows: rows(paged.cards, key) };
}

// ---- Search ---------------------------------------------------------------

const searches = new Map<string, Paged>();

async function searchProducts(api: string, query: string, pages: number): Promise<Result<'searchProducts'>> {
  const q = query.trim();
  if (q === '' || api === '') return { query: q, loaded: false, total: 0, hasNext: false, results: [] };
  let paged = searches.get(q);
  if (!paged || paged.pages > pages) paged = { title: '', description: '', total: 0, cards: [], cursor: null, hasNext: true, pages: 0 };
  while (paged.pages < pages && (paged.pages === 0 || paged.hasNext)) {
    const variables: Record<string, unknown> = { query: q, first: PAGE };
    if (paged.cursor) variables.after = paged.cursor;
    const data = await gql(api, 'Search', SEARCH, variables);
    const s = data.search;
    const offset = paged.cards.length;
    const nodes = (s?.nodes ?? []).filter((p: any) => p && p.id);
    paged = {
      title: '',
      description: '',
      total: Number(s?.totalCount ?? 0),
      cards: paged.cards.concat(nodes.map((p: any, i: number) => card(p, offset + i, 240))),
      cursor: s?.pageInfo?.endCursor ?? null,
      hasNext: Boolean(s?.pageInfo?.hasNextPage),
      pages: paged.pages + 1,
    };
    searches.set(q, paged);
  }
  return {
    query: q,
    loaded: true,
    total: paged.total,
    hasNext: paged.hasNext,
    results: paged.cards.map((c) => ({ key: `${q}:${c.id}`, kind: 'card', card: c })),
  };
}

// ---- Product --------------------------------------------------------------

type Detail = Result<'loadProducts'>['items'][number];
const products = new Map<string, Detail>();

function failedDetail(handle: string): Detail {
  return { handle, status: 'error', title: '', description: '', images: [], options: [], variants: [], initialVariant: '', recs: [] };
}

async function fetchProduct(api: string, handle: string): Promise<Detail> {
  const data = await gql(api, 'Product', PRODUCT, { handle });
  const p = data.product;
  if (!p) throw new Error('No such product');
  const variants = (p.variants?.nodes ?? []).map((v: any) => ({
    id: v.id,
    title: v.title,
    available: Boolean(v.availableForSale),
    options: (v.selectedOptions ?? []).map((o: any) => ({ name: o.name, value: o.value })),
    price: money(v.price),
    compare: amount(v.compareAtPrice) > amount(v.price) ? money(v.compareAtPrice) : '',
  }));
  const options = (p.options ?? [])
    .map((o: any) => ({ name: o.name as string, values: (o.optionValues ?? []).map((v: any) => v.name as string) }))
    .filter((o: { name: string; values: string[] }) => !(o.name === 'Title' && o.values.length === 1 && o.values[0] === 'Default Title'));
  const initial = variants.find((v: { available: boolean }) => v.available) ?? variants[0];
  return {
    handle,
    status: 'ok',
    title: p.title,
    description: p.description ?? '',
    images: (p.images?.nodes ?? []).slice(0, 10).map((i: any) => sized(i.url, 1080)),
    options,
    variants,
    initialVariant: initial?.id ?? '',
    recs: (data.productRecommendations ?? []).map((r: any, i: number) => card(r, i, 480)),
  };
}

async function loadProducts(api: string, handles: string[]): Promise<Result<'loadProducts'>> {
  if (api === '') return { items: [] };
  const unique = [...new Set(handles)];
  const items = await Promise.all(unique.map(async (h) => {
    const kept = products.get(h);
    if (kept) return kept;
    try {
      const detail = await fetchProduct(api, h);
      products.set(h, detail);
      return detail;
    } catch {
      return failedDetail(h);
    }
  }));
  return { items };
}

// ---- Cart -----------------------------------------------------------------

const EMPTY_CART: Cart = { id: '', checkoutUrl: '', totalQuantity: 0, subtotal: '$0.00', lines: [] };
let cart: Cart = EMPTY_CART;
let seq = 0;

function toCart(c: any): Cart {
  if (!c) return cart;
  return {
    id: c.id,
    checkoutUrl: c.checkoutUrl,
    totalQuantity: Number(c.totalQuantity ?? 0),
    subtotal: money(c.cost?.subtotalAmount),
    lines: (c.lines?.nodes ?? []).map((l: any, index: number) => {
      const m = l.merchandise ?? {};
      return {
        id: l.id,
        index,
        title: m.product?.title ?? '',
        variant: m.title && m.title !== 'Default Title' ? m.title : '',
        image: sized(m.image?.url ?? m.product?.featuredImage?.url, 240),
        quantity: Number(l.quantity ?? 0),
        total: money(l.cost?.totalAmount),
      };
    }),
  };
}

async function cartCall(api: string, operationName: string, query: string, variables: Record<string, unknown>, field: string): Promise<Result<'addToCart'>> {
  seq += 1;
  try {
    const data = await gql(api, operationName, query, variables);
    const payload = data[field];
    cart = toCart(payload?.cart);
    const error = payload?.userErrors?.[0]?.message ?? '';
    return { seq, ok: error === '', error, cart };
  } catch {
    return { seq, ok: false, error: 'Check your connection and try again.', cart };
  }
}

function addToCart(api: string, variantId: string) {
  const lines = [{ merchandiseId: variantId, quantity: 1 }];
  return cart.id === ''
    ? cartCall(api, 'CartCreate', CART_CREATE, { lines }, 'cartCreate')
    : cartCall(api, 'CartLinesAdd', CART_LINES_ADD, { cartId: cart.id, lines }, 'cartLinesAdd');
}

function updateLine(api: string, lineId: string, quantity: number) {
  return cartCall(api, 'CartLinesUpdate', CART_LINES_UPDATE, { cartId: cart.id, lines: [{ id: lineId, quantity: Math.max(0, quantity) }] }, 'cartLinesUpdate');
}

// ---- benchmark marker -----------------------------------------------------

function homeReady(native: Native): Result<'homeReady'> {
  if (native?.available) {
    try {
      native.call({ op: 'ready' });
    } catch {
      // No module on this host.
    }
  }
  return { ok: true };
}

const sources: Sources = {
  shopEndpoint: (_args, _store, _storage, native): Result<'shopEndpoint'> => ({ url: endpointFor(native) }),
  loadHome: ([api]) => loadHome(api),
  loadCollection: ([api, handle, sort, pages]) => loadCollection(api, handle, sort, pages),
  searchProducts: ([api, query, pages]) => searchProducts(api, query, pages),
  loadProducts: ([api, handles]) => loadProducts(api, handles),
  addToCart: ([api, variantId]) => addToCart(api, variantId),
  updateLine: ([api, lineId, quantity]) => updateLine(api, lineId, quantity),
  homeReady: (_args, _store, _storage, native) => homeReady(native),
};

export const answer: Answer = (source, args, store, storage, native) =>
  sources[source](args, store, storage, native);
