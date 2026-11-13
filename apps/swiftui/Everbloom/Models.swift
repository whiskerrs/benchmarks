import Foundation

struct Nodes<T: Decodable>: Decodable {
    let nodes: [T]
}

struct Money: Decodable, Hashable {
    let amount: String
    let currencyCode: String

    var value: Double { Double(amount) ?? 0 }
    var formatted: String { String(format: "$%.2f", value) }
}

struct ImageRef: Decodable, Hashable {
    let url: String
    let altText: String?
}

struct PriceRange: Decodable, Hashable {
    let minVariantPrice: Money
}

struct PageInfo: Decodable {
    let hasNextPage: Bool
    let endCursor: String?
}

struct ProductCardModel: Decodable, Hashable, Identifiable {
    let id: String
    let handle: String
    let title: String
    let featuredImage: ImageRef?
    let priceRange: PriceRange
    let compareAtPriceRange: PriceRange?

    var price: Money { priceRange.minVariantPrice }
    var compareAt: Money? { compareAtPriceRange?.minVariantPrice }
}

/// Search nodes are a union; anything that is not a Product decodes to nil.
struct OptionalProductCard: Decodable {
    let product: ProductCardModel?
    init(from decoder: Decoder) throws {
        product = try? ProductCardModel(from: decoder)
    }
}

// MARK: Home

struct CollectionSummary: Decodable, Identifiable {
    let id: String
    let handle: String
    let title: String
    let image: ImageRef?
}

struct HomeData: Decodable {
    let collections: Nodes<CollectionSummary>
    let products: Nodes<ProductCardModel>
}

// MARK: Collection

enum SortOption: String, CaseIterable, Identifiable {
    case featured, bestSelling, priceAsc, priceDesc
    var id: String { rawValue }

    var label: String {
        switch self {
        case .featured: "Featured"
        case .bestSelling: "Best selling"
        case .priceAsc: "Price: low to high"
        case .priceDesc: "Price: high to low"
        }
    }

    var identifier: String {
        switch self {
        case .featured: "sort-featured"
        case .bestSelling: "sort-best-selling"
        case .priceAsc: "sort-price-asc"
        case .priceDesc: "sort-price-desc"
        }
    }

    var sortKey: String {
        switch self {
        case .featured: "COLLECTION_DEFAULT"
        case .bestSelling: "BEST_SELLING"
        case .priceAsc, .priceDesc: "PRICE"
        }
    }

    var reverse: Bool { self == .priceDesc }
}

struct ProductConnection: Decodable {
    let pageInfo: PageInfo
    let nodes: [ProductCardModel]
}

struct CollectionDetail: Decodable {
    let id: String
    let title: String
    let description: String
    let products: ProductConnection
}

struct CollectionProductsData: Decodable {
    let collection: CollectionDetail?
}

// MARK: Search

struct SearchConnection: Decodable {
    let totalCount: Int
    let pageInfo: PageInfo
    let nodes: [OptionalProductCard]
}

struct SearchData: Decodable {
    let search: SearchConnection
}

// MARK: Product

struct OptionValue: Decodable, Hashable {
    let name: String
}

struct ProductOption: Decodable, Hashable {
    let name: String
    let optionValues: [OptionValue]
}

struct SelectedOption: Decodable, Hashable {
    let name: String
    let value: String
}

struct Variant: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let availableForSale: Bool
    let selectedOptions: [SelectedOption]
    let price: Money
    let compareAtPrice: Money?

    func value(for option: String) -> String? {
        selectedOptions.first { $0.name == option }?.value
    }
}

struct ProductDetail: Decodable {
    let id: String
    let handle: String
    let title: String
    let description: String
    let images: Nodes<ImageRef>
    let options: [ProductOption]
    let variants: Nodes<Variant>
}

struct ProductData: Decodable {
    let product: ProductDetail?
    let productRecommendations: [ProductCardModel]?
}

// MARK: Cart

struct CartProduct: Decodable {
    let handle: String
    let title: String
    let featuredImage: ImageRef?
}

struct Merchandise: Decodable {
    let id: String
    let title: String
    let image: ImageRef?
    let product: CartProduct
}

struct LineCost: Decodable {
    let totalAmount: Money
}

struct CartLine: Decodable, Identifiable {
    let id: String
    let quantity: Int
    let cost: LineCost
    let merchandise: Merchandise
}

struct CartCost: Decodable {
    let subtotalAmount: Money
}

struct Cart: Decodable {
    let id: String
    let checkoutUrl: String
    let totalQuantity: Int
    let cost: CartCost
    let lines: Nodes<CartLine>
}

struct UserError: Decodable {
    let field: [String]?
    let message: String
}

struct CartPayload: Decodable {
    let cart: Cart?
    let userErrors: [UserError]
}

struct CartCreateData: Decodable { let cartCreate: CartPayload }
struct CartLinesAddData: Decodable { let cartLinesAdd: CartPayload }
struct CartLinesUpdateData: Decodable { let cartLinesUpdate: CartPayload }
