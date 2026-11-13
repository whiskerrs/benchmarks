import Foundation

struct Money: Decodable {
    let amount: String
    let currencyCode: String
    var value: Double { Double(amount) ?? 0 }
}

struct ImageRef: Decodable {
    let url: String
    let altText: String?
}

struct Nodes<T: Decodable>: Decodable {
    let nodes: [T]
}

struct PageInfo: Decodable {
    let hasNextPage: Bool
    let endCursor: String?
}

struct PriceRange: Decodable {
    let minVariantPrice: Money
}

struct ProductCard: Decodable {
    let id: String
    let handle: String
    let title: String
    let featuredImage: ImageRef?
    let priceRange: PriceRange
    let compareAtPriceRange: PriceRange?

    var price: Money { priceRange.minVariantPrice }
    var compareAt: Money? { compareAtPriceRange?.minVariantPrice }
}

struct Collection: Decodable {
    let id: String
    let handle: String
    let title: String
    let image: ImageRef?
}

struct HomeData: Decodable {
    let collections: Nodes<Collection>
    let products: Nodes<ProductCard>
}

struct ProductConnection: Decodable {
    let pageInfo: PageInfo
    let nodes: [ProductCard]
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

struct SearchConnection: Decodable {
    let totalCount: Int
    let pageInfo: PageInfo
    let nodes: [ProductCard]
}

struct SearchData: Decodable {
    let search: SearchConnection
}

struct OptionValue: Decodable {
    let name: String
}

struct ProductOption: Decodable {
    let name: String
    let optionValues: [OptionValue]
}

struct SelectedOption: Decodable {
    let name: String
    let value: String
}

struct Variant: Decodable {
    let id: String
    let title: String
    let availableForSale: Bool
    let selectedOptions: [SelectedOption]
    let price: Money
    let compareAtPrice: Money?
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
    let productRecommendations: [ProductCard]?
}

struct MerchandiseProduct: Decodable {
    let handle: String
    let title: String
    let featuredImage: ImageRef?
}

struct Merchandise: Decodable {
    let id: String
    let title: String
    let image: ImageRef?
    let product: MerchandiseProduct
}

struct CartLineCost: Decodable {
    let totalAmount: Money
}

struct CartLine: Decodable {
    let id: String
    let quantity: Int
    let cost: CartLineCost
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

struct CartCreateData: Decodable { let cartCreate: CartPayload? }
struct CartLinesAddData: Decodable { let cartLinesAdd: CartPayload? }
struct CartLinesUpdateData: Decodable { let cartLinesUpdate: CartPayload? }
