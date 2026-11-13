import Foundation

enum APIError: Error {
    case badStatus
    case noData
}

enum API {
    static let endpoint: URL = {
        if let value = ProcessInfo.processInfo.environment["SHOP_API_URL"],
           !value.trimmingCharacters(in: .whitespaces).isEmpty,
           let url = URL(string: value.trimmingCharacters(in: .whitespaces)) {
            return url
        }
        return URL(string: "https://apparel-large-catalog.mock.shop/api")!
    }()

    private struct Envelope<T: Decodable>: Decodable {
        let data: T?
    }

    static func send<T: Decodable>(_ operationName: String, _ document: String, _ variables: [String: Any] = [:]) async throws -> T {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "operationName": operationName,
            "query": document,
            "variables": variables,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus
        }
        let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
        guard let value = envelope.data else { throw APIError.noData }
        return value
    }

    // MARK: Operations

    static func home() async throws -> HomeData {
        try await send("Home", Documents.home)
    }

    static func collectionProducts(handle: String, after: String?, sort: SortOption) async throws -> CollectionProductsData {
        var vars: [String: Any] = [
            "handle": handle,
            "first": 24,
            "sortKey": sort.sortKey,
            "reverse": sort.reverse,
        ]
        if let after { vars["after"] = after }
        return try await send("CollectionProducts", Documents.collectionProducts, vars)
    }

    static func search(query: String, after: String?) async throws -> SearchData {
        var vars: [String: Any] = ["query": query, "first": 24]
        if let after { vars["after"] = after }
        return try await send("Search", Documents.search, vars)
    }

    static func product(handle: String) async throws -> ProductData {
        try await send("Product", Documents.product, ["handle": handle])
    }

    static func cartCreate(merchandiseId: String) async throws -> CartPayload {
        let data: CartCreateData = try await send("CartCreate", Documents.cartCreate, [
            "lines": [["merchandiseId": merchandiseId, "quantity": 1]],
        ])
        return data.cartCreate
    }

    static func cartLinesAdd(cartId: String, merchandiseId: String) async throws -> CartPayload {
        let data: CartLinesAddData = try await send("CartLinesAdd", Documents.cartLinesAdd, [
            "cartId": cartId,
            "lines": [["merchandiseId": merchandiseId, "quantity": 1]],
        ])
        return data.cartLinesAdd
    }

    static func cartLinesUpdate(cartId: String, lineId: String, quantity: Int) async throws -> CartPayload {
        let data: CartLinesUpdateData = try await send("CartLinesUpdate", Documents.cartLinesUpdate, [
            "cartId": cartId,
            "lines": [["id": lineId, "quantity": quantity]],
        ])
        return data.cartLinesUpdate
    }
}

/// Operation documents, copied verbatim from spec/storefront.graphql.
/// Each document includes the fragments it uses.
enum Documents {
    static let productCard = """
    fragment ProductCard on Product {
      id
      handle
      title
      featuredImage { url altText }
      priceRange { minVariantPrice { amount currencyCode } }
      compareAtPriceRange { minVariantPrice { amount currencyCode } }
    }
    """

    static let cartFields = """
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
    """

    static let home = """
    query Home {
      collections(first: 20) {
        nodes { id handle title image { url altText } }
      }
      products(first: 10, sortKey: BEST_SELLING) {
        nodes { ...ProductCard }
      }
    }

    """ + productCard

    static let collectionProducts = """
    query CollectionProducts($handle: String!, $first: Int!, $after: String, $sortKey: ProductCollectionSortKeys!, $reverse: Boolean!) {
      collection(handle: $handle) {
        id
        title
        description
        products(first: $first, after: $after, sortKey: $sortKey, reverse: $reverse) {
          pageInfo { hasNextPage endCursor }
          nodes { ...ProductCard }
        }
      }
    }

    """ + productCard

    static let search = """
    query Search($query: String!, $first: Int!, $after: String) {
      search(query: $query, first: $first, after: $after, types: PRODUCT) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes { ... on Product { ...ProductCard } }
      }
    }

    """ + productCard

    static let product = """
    query Product($handle: String!) {
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
    }

    """ + productCard

    static let cartCreate = """
    mutation CartCreate($lines: [CartLineInput!]!) {
      cartCreate(input: { lines: $lines }) {
        cart { ...CartFields }
        userErrors { field message }
      }
    }

    """ + cartFields

    static let cartLinesAdd = """
    mutation CartLinesAdd($cartId: ID!, $lines: [CartLineInput!]!) {
      cartLinesAdd(cartId: $cartId, lines: $lines) {
        cart { ...CartFields }
        userErrors { field message }
      }
    }

    """ + cartFields

    static let cartLinesUpdate = """
    mutation CartLinesUpdate($cartId: ID!, $lines: [CartLineUpdateInput!]!) {
      cartLinesUpdate(cartId: $cartId, lines: $lines) {
        cart { ...CartFields }
        userErrors { field message }
      }
    }

    """ + cartFields
}
