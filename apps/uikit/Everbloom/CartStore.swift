import Foundation

/// In-memory cart. Every operation replaces the cart with the one in the response.
final class CartStore {
    static let shared = CartStore()
    static let didChange = Notification.Name("CartStoreDidChange")

    private(set) var cart: Cart?
    private(set) var isBusy = false {
        didSet { notify() }
    }

    var totalQuantity: Int { cart?.totalQuantity ?? 0 }
    var lines: [CartLine] { cart?.lines.nodes ?? [] }

    /// Adds one of the variant. Completion receives an error message to show, or nil on success.
    @MainActor
    func add(variantId: String, completion: @escaping (String?) -> Void) {
        perform({ [cart] in
            if let cart {
                return try await API.shared.cartLinesAdd(cartId: cart.id, variantId: variantId)
            }
            return try await API.shared.cartCreate(variantId: variantId)
        }, completion: completion)
    }

    @MainActor
    func update(lineId: String, quantity: Int, completion: @escaping (String?) -> Void) {
        guard let cart else { return }
        perform({
            try await API.shared.cartLinesUpdate(cartId: cart.id, lineId: lineId, quantity: max(0, quantity))
        }, completion: completion)
    }

    @MainActor
    private func perform(_ operation: @escaping () async throws -> CartPayload?, completion: @escaping (String?) -> Void) {
        guard !isBusy else { return }
        isBusy = true
        Task { @MainActor in
            var message: String?
            do {
                let payload = try await operation()
                if let newCart = payload?.cart { cart = newCart }
                message = payload?.userErrors.first?.message
            } catch {
                message = "Couldn't update your cart. Check your connection and try again."
            }
            isBusy = false
            completion(message)
        }
    }

    private func notify() {
        NotificationCenter.default.post(name: CartStore.didChange, object: self)
    }
}
