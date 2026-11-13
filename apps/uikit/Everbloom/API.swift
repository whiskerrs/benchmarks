import Foundation

/// GraphQL documents, copied verbatim from spec/storefront.graphql.
/// Each request sends its operation plus the fragments it uses.
enum GQL {
    static let productCardFragment = """
    fragment ProductCard on Product {
      id
      handle
      title
      featuredImage { url altText }
      priceRange { minVariantPrice { amount currencyCode } }
      compareAtPriceRange { minVariantPrice { amount currencyCode } }
    }
    """

    static let cartFieldsFragment = """
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

    static let home = productCardFragment + "\n\n" + """
    query Home {
      collections(first: 20) {
        nodes { id handle title image { url altText } }
      }
      products(first: 10, sortKey: BEST_SELLING) {
        nodes { ...ProductCard }
      }
    }
    """

    static let collectionProducts = productCardFragment + "\n\n" + """
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
    """

    static let search = productCardFragment + "\n\n" + """
    query Search($query: String!, $first: Int!, $after: String) {
      search(query: $query, first: $first, after: $after, types: PRODUCT) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes { ... on Product { ...ProductCard } }
      }
    }
    """

    static let product = productCardFragment + "\n\n" + """
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
    """

    static let cartCreate = cartFieldsFragment + "\n\n" + """
    mutation CartCreate($lines: [CartLineInput!]!) {
      cartCreate(input: { lines: $lines }) {
        cart { ...CartFields }
        userErrors { field message }
      }
    }
    """

    static let cartLinesAdd = cartFieldsFragment + "\n\n" + """
    mutation CartLinesAdd($cartId: ID!, $lines: [CartLineInput!]!) {
      cartLinesAdd(cartId: $cartId, lines: $lines) {
        cart { ...CartFields }
        userErrors { field message }
      }
    }
    """

    static let cartLinesUpdate = cartFieldsFragment + "\n\n" + """
    mutation CartLinesUpdate($cartId: ID!, $lines: [CartLineUpdateInput!]!) {
      cartLinesUpdate(cartId: $cartId, lines: $lines) {
        cart { ...CartFields }
        userErrors { field message }
      }
    }
    """
}

enum APIError: Error {
    case http(Int)
    case graphQL(String)
    case noData
}

private struct GraphQLError: Decodable { let message: String }
private struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

enum CollectionSort: CaseIterable {
    case featured, bestSelling, priceAsc, priceDesc

    var label: String {
        switch self {
        case .featured: return "Featured"
        case .bestSelling: return "Best selling"
        case .priceAsc: return "Price: low to high"
        case .priceDesc: return "Price: high to low"
        }
    }
    var sortKey: String {
        switch self {
        case .featured: return "COLLECTION_DEFAULT"
        case .bestSelling: return "BEST_SELLING"
        case .priceAsc, .priceDesc: return "PRICE"
        }
    }
    var reverse: Bool { self == .priceDesc }
    var identifier: String {
        switch self {
        case .featured: return "sort-featured"
        case .bestSelling: return "sort-best-selling"
        case .priceAsc: return "sort-price-asc"
        case .priceDesc: return "sort-price-desc"
        }
    }
}

final class API {
    static let shared = API()

    static let defaultEndpoint = "https://apparel-large-catalog.mock.shop/api"

    let endpoint: URL
    private let session: URLSession

    private init() {
        let override = ProcessInfo.processInfo.environment["SHOP_API_URL"] ?? ""
        let raw = override.isEmpty ? API.defaultEndpoint : override
        endpoint = URL(string: raw) ?? URL(string: API.defaultEndpoint)!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    func send<T: Decodable>(_ operationName: String, _ query: String, _ variables: [String: Any], as type: T.Type) async throws -> T {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["operationName": operationName, "query": query, "variables": variables]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)
        if let result = decoded.data { return result }
        if let message = decoded.errors?.first?.message { throw APIError.graphQL(message) }
        throw APIError.noData
    }

    // MARK: Operations

    func home() async throws -> HomeData {
        try await send("Home", GQL.home, [:], as: HomeData.self)
    }

    func collectionProducts(handle: String, after: String?, sort: CollectionSort) async throws -> CollectionProductsData {
        let vars: [String: Any] = [
            "handle": handle,
            "first": 24,
            "after": after ?? NSNull(),
            "sortKey": sort.sortKey,
            "reverse": sort.reverse,
        ]
        return try await send("CollectionProducts", GQL.collectionProducts, vars, as: CollectionProductsData.self)
    }

    func search(query: String, after: String?) async throws -> SearchData {
        let vars: [String: Any] = ["query": query, "first": 24, "after": after ?? NSNull()]
        return try await send("Search", GQL.search, vars, as: SearchData.self)
    }

    func product(handle: String) async throws -> ProductData {
        try await send("Product", GQL.product, ["handle": handle], as: ProductData.self)
    }

    func cartCreate(variantId: String) async throws -> CartPayload? {
        let lines: [[String: Any]] = [["merchandiseId": variantId, "quantity": 1]]
        return try await send("CartCreate", GQL.cartCreate, ["lines": lines], as: CartCreateData.self).cartCreate
    }

    func cartLinesAdd(cartId: String, variantId: String) async throws -> CartPayload? {
        let lines: [[String: Any]] = [["merchandiseId": variantId, "quantity": 1]]
        return try await send("CartLinesAdd", GQL.cartLinesAdd, ["cartId": cartId, "lines": lines], as: CartLinesAddData.self).cartLinesAdd
    }

    func cartLinesUpdate(cartId: String, lineId: String, quantity: Int) async throws -> CartPayload? {
        let lines: [[String: Any]] = [["id": lineId, "quantity": quantity]]
        return try await send("CartLinesUpdate", GQL.cartLinesUpdate, ["cartId": cartId, "lines": lines], as: CartLinesUpdateData.self).cartLinesUpdate
    }
}
