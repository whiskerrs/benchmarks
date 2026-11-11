import { Http } from '@nativescript/core';

declare const __SHOP_API_URL__: string;

const DEFAULT_ENDPOINT = 'https://apparel-large-catalog.mock.shop/api';

function resolveEndpoint(): string {
  if (__APPLE__) {
    const env = NSProcessInfo.processInfo.environment.objectForKey('SHOP_API_URL') as string;
    if (env && `${env}`.length > 0) {
      return `${env}`;
    }
  }
  if (typeof __SHOP_API_URL__ === 'string' && __SHOP_API_URL__.length > 0) {
    return __SHOP_API_URL__;
  }
  return DEFAULT_ENDPOINT;
}

export const ENDPOINT = resolveEndpoint();

// Operations from spec/storefront.graphql, verbatim. Each request carries the
// operation plus the fragments it spreads.
const PRODUCT_CARD = `fragment ProductCard on Product {
  id
  handle
  title
  featuredImage { url altText }
  priceRange { minVariantPrice { amount currencyCode } }
  compareAtPriceRange { minVariantPrice { amount currencyCode } }
}`;

const CART_FIELDS = `fragment CartFields on Cart {
  id
  checkoutUrl
  totalQuantity
  cost { subtotalAmount { amount currencyCode } }
  lines(first: 100) {
    nodes {
      id
      quantity
      cost { totalAmount { amount currencyCode } }
      merchandise {
        ... on ProductVariant {
          id
          title
          image { url altText }
          product { handle title featuredImage { url altText } }
        }
      }
    }
  }
}`;

const HOME = `query Home {
  collections(first: 20) {
    nodes { id handle title image { url altText } }
  }
  products(first: 10, sortKey: BEST_SELLING) {
    nodes { ...ProductCard }
  }
}`;

const COLLECTION_PRODUCTS = `query CollectionProducts($handle: String!, $first: Int!, $after: String, $sortKey: ProductCollectionSortKeys!, $reverse: Boolean!) {
  collection(handle: $handle) {
    id
    title
    description
    products(first: $first, after: $after, sortKey: $sortKey, reverse: $reverse) {
      pageInfo { hasNextPage endCursor }
      nodes { ...ProductCard }
    }
  }
}`;

const SEARCH = `query Search($query: String!, $first: Int!, $after: String) {
  search(query: $query, first: $first, after: $after, types: PRODUCT) {
    totalCount
    pageInfo { hasNextPage endCursor }
    nodes { ... on Product { ...ProductCard } }
  }
}`;

const PRODUCT = `query Product($handle: String!) {
  product(handle: $handle) {
    id
    handle
    title
    description
    images(first: 10) { nodes { url altText } }
    options { name optionValues { name } }
    variants(first: 100) {
      nodes {
        id
        title
        availableForSale
        selectedOptions { name value }
        price { amount currencyCode }
        compareAtPrice { amount currencyCode }
      }
    }
  }
  productRecommendations(productHandle: $handle) { ...ProductCard }
}`;

const CART_CREATE = `mutation CartCreate($lines: [CartLineInput!]!) {
  cartCreate(input: { lines: $lines }) {
    cart { ...CartFields }
    userErrors { field message }
  }
}`;

const CART_LINES_ADD = `mutation CartLinesAdd($cartId: ID!, $lines: [CartLineInput!]!) {
  cartLinesAdd(cartId: $cartId, lines: $lines) {
    cart { ...CartFields }
    userErrors { field message }
  }
}`;

const CART_LINES_UPDATE = `mutation CartLinesUpdate($cartId: ID!, $lines: [CartLineUpdateInput!]!) {
  cartLinesUpdate(cartId: $cartId, lines: $lines) {
    cart { ...CartFields }
    userErrors { field message }
  }
}`;

const DOCUMENTS = {
  Home: `${HOME}\n\n${PRODUCT_CARD}`,
  CollectionProducts: `${COLLECTION_PRODUCTS}\n\n${PRODUCT_CARD}`,
  Search: `${SEARCH}\n\n${PRODUCT_CARD}`,
  Product: `${PRODUCT}\n\n${PRODUCT_CARD}`,
  CartCreate: `${CART_CREATE}\n\n${CART_FIELDS}`,
  CartLinesAdd: `${CART_LINES_ADD}\n\n${CART_FIELDS}`,
  CartLinesUpdate: `${CART_LINES_UPDATE}\n\n${CART_FIELDS}`,
};

export type OperationName = keyof typeof DOCUMENTS;

export interface Money {
  amount: string;
  currencyCode: string;
}
export interface Image {
  url: string;
  altText: string | null;
}
export interface ProductCard {
  id: string;
  handle: string;
  title: string;
  featuredImage: Image | null;
  priceRange: { minVariantPrice: Money };
  compareAtPriceRange: { minVariantPrice: Money } | null;
}
export interface PageInfo {
  hasNextPage: boolean;
  endCursor: string | null;
}
export interface Collection {
  id: string;
  handle: string;
  title: string;
  image: Image | null;
}
export interface Variant {
  id: string;
  title: string;
  availableForSale: boolean;
  selectedOptions: { name: string; value: string }[];
  price: Money;
  compareAtPrice: Money | null;
}
export interface ProductDetail {
  id: string;
  handle: string;
  title: string;
  description: string;
  images: { nodes: Image[] };
  options: { name: string; optionValues: { name: string }[] }[];
  variants: { nodes: Variant[] };
}
export interface CartLine {
  id: string;
  quantity: number;
  cost: { totalAmount: Money };
  merchandise: {
    id: string;
    title: string;
    image: Image | null;
    product: { handle: string; title: string; featuredImage: Image | null };
  };
}
export interface Cart {
  id: string;
  checkoutUrl: string;
  totalQuantity: number;
  cost: { subtotalAmount: Money };
  lines: { nodes: CartLine[] };
}
export interface CartPayload {
  cart: Cart | null;
  userErrors: { field: string[] | null; message: string }[];
}

export async function gql<T>(operationName: OperationName, variables: Record<string, unknown> = {}): Promise<T> {
  const response = await Http.request({
    url: ENDPOINT,
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    content: JSON.stringify({ operationName, query: DOCUMENTS[operationName], variables }),
    timeout: 30000,
  });
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw new Error(`HTTP ${response.statusCode}`);
  }
  const body = response.content.toJSON() as { data?: T; errors?: { message: string }[] };
  if (!body || !body.data) {
    throw new Error(body?.errors?.[0]?.message ?? 'Empty response');
  }
  return body.data;
}
