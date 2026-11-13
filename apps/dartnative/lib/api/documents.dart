// GraphQL documents sent to the Storefront API.
//
// Copied verbatim from spec/storefront.graphql. Each document is the
// operation followed by the fragment it spreads.

// ignore_for_file: constant_identifier_names

const String _fragProductCard = r'''
fragment ProductCard on Product {
  id
  handle
  title
  featuredImage { url altText }
  priceRange { minVariantPrice { amount currencyCode } }
  compareAtPriceRange { minVariantPrice { amount currencyCode } }
}
''';

const String _fragCartFields = r'''
fragment CartFields on Cart {
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
}
''';

const String docHome = '''
query Home {
  collections(first: 20) {
    nodes { id handle title image { url altText } }
  }
  products(first: 10, sortKey: BEST_SELLING) {
    nodes { ...ProductCard }
  }
}

$_fragProductCard''';

const String docCollectionProducts = '''
query CollectionProducts(\$handle: String!, \$first: Int!, \$after: String, \$sortKey: ProductCollectionSortKeys!, \$reverse: Boolean!) {
  collection(handle: \$handle) {
    id
    title
    description
    products(first: \$first, after: \$after, sortKey: \$sortKey, reverse: \$reverse) {
      pageInfo { hasNextPage endCursor }
      nodes { ...ProductCard }
    }
  }
}

$_fragProductCard''';

const String docSearch = '''
query Search(\$query: String!, \$first: Int!, \$after: String) {
  search(query: \$query, first: \$first, after: \$after, types: PRODUCT) {
    totalCount
    pageInfo { hasNextPage endCursor }
    nodes { ... on Product { ...ProductCard } }
  }
}

$_fragProductCard''';

const String docProduct = '''
query Product(\$handle: String!) {
  product(handle: \$handle) {
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
  productRecommendations(productHandle: \$handle) { ...ProductCard }
}

$_fragProductCard''';

const String docCartCreate = '''
mutation CartCreate(\$lines: [CartLineInput!]!) {
  cartCreate(input: { lines: \$lines }) {
    cart { ...CartFields }
    userErrors { field message }
  }
}

$_fragCartFields''';

const String docCartLinesAdd = '''
mutation CartLinesAdd(\$cartId: ID!, \$lines: [CartLineInput!]!) {
  cartLinesAdd(cartId: \$cartId, lines: \$lines) {
    cart { ...CartFields }
    userErrors { field message }
  }
}

$_fragCartFields''';

const String docCartLinesUpdate = '''
mutation CartLinesUpdate(\$cartId: ID!, \$lines: [CartLineUpdateInput!]!) {
  cartLinesUpdate(cartId: \$cartId, lines: \$lines) {
    cart { ...CartFields }
    userErrors { field message }
  }
}

$_fragCartFields''';
