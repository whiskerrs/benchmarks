import SafariServices
import SwiftUI

@MainActor
@Observable
final class CartStore {
    /// In-memory only; never persisted.
    var cart: Cart?
    var isBusy = false
    var alertMessage: String?

    /// Adds one of the variant. Returns true when the line was added without errors.
    func add(variantId: String) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        do {
            let payload: CartPayload
            if let id = cart?.id {
                payload = try await API.cartLinesAdd(cartId: id, merchandiseId: variantId)
            } else {
                payload = try await API.cartCreate(merchandiseId: variantId)
            }
            return apply(payload)
        } catch {
            alertMessage = "Couldn't update the cart. Check your connection and try again."
            return false
        }
    }

    func update(lineId: String, quantity: Int) async {
        guard let id = cart?.id else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let payload = try await API.cartLinesUpdate(cartId: id, lineId: lineId, quantity: max(0, quantity))
            _ = apply(payload)
        } catch {
            alertMessage = "Couldn't update the cart. Check your connection and try again."
        }
    }

    private func apply(_ payload: CartPayload) -> Bool {
        if let newCart = payload.cart {
            cart = newCart
        }
        if let first = payload.userErrors.first {
            alertMessage = first.message
            return false
        }
        return payload.cart != nil
    }
}

struct CheckoutURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct CartView: View {
    @Environment(CartStore.self) private var store
    @Environment(AppModel.self) private var app
    @State private var checkout: CheckoutURL?

    var body: some View {
        VStack(spacing: 0) {
            Text("Cart")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 44)

            if let cart = store.cart, !cart.lines.nodes.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(cart.lines.nodes.enumerated()), id: \.element.id) { index, line in
                            CartLineRow(line: line, index: index)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    summary(cart)
                }
            } else {
                emptyState
            }
        }
        .background(Color.background)
        .sheet(item: $checkout) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    private func summary(_ cart: Cart) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Subtotal")
                    .font(.system(size: 15))
                Spacer()
                Text(cart.cost.subtotalAmount.formatted)
                    .font(.system(size: 17, weight: .bold))
                    .accessibilityIdentifier("cart-subtotal")
            }
            .foregroundStyle(Color.text)
            Text("Taxes and shipping are calculated at checkout.")
                .font(.system(size: 13))
                .foregroundStyle(Color.textMuted)
            Button {
                if let url = URL(string: cart.checkoutUrl) {
                    checkout = CheckoutURL(url: url)
                }
            } label: {
                Text("Check out")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.text))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("checkout")
        }
        .padding(16)
        .background(Color.background)
        .overlay(alignment: .top) { Color.border.frame(height: 1) }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Your cart is empty")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.text)
            Text("Items you add will appear here.")
                .font(.system(size: 15))
                .foregroundStyle(Color.textMuted)
            Button {
                app.tab = .home
            } label: {
                Text("Start shopping")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.text))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CartLineRow: View {
    @Environment(CartStore.self) private var store
    let line: CartLine
    let index: Int

    var body: some View {
        let merch = line.merchandise
        HStack(alignment: .top, spacing: 12) {
            RemoteImage(url: imageURL(merch.image ?? merch.product.featuredImage, width: 240))
                .frame(width: 80, height: 107)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(merch.product.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.text)
                if merch.title != "Default Title" {
                    Text(merch.title)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textMuted)
                }
                Spacer(minLength: 0)
                HStack {
                    stepper
                    Spacer()
                    Text(line.cost.totalAmount.formatted)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.text)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 107, alignment: .leading)
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Color.border.frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cart-line-\(index)")
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            stepButton(.minus, "Decrease quantity", "qty-dec-\(index)", line.quantity - 1)
            Text("\(line.quantity)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.text)
                .frame(minWidth: 24)
            stepButton(.plus, "Increase quantity", "qty-inc-\(index)", line.quantity + 1)
        }
        .frame(height: 36)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.border, lineWidth: 1))
    }

    private func stepButton(_ icon: IconKind, _ label: String, _ id: String, _ quantity: Int) -> some View {
        Button {
            Task { await store.update(lineId: line.id, quantity: quantity) }
        } label: {
            Icon(kind: icon, size: 16, lineWidth: 1.4)
                .foregroundStyle(Color.text)
                .frame(width: 36, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isBusy)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { dismiss() }
    }
}
