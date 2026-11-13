import SwiftUI

@main
struct EverbloomApp: App {
    init() {
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

enum Tab: Hashable {
    case home, search, cart
}

enum Route: Hashable {
    case collection(handle: String, title: String)
    case product(handle: String)
}

@MainActor
@Observable
final class AppModel {
    var tab: Tab = .home
    var homePath: [Route] = []
    var searchPath: [Route] = []

    var showsTabBar: Bool {
        let path: [Route]
        switch tab {
        case .home: path = homePath
        case .search: path = searchPath
        case .cart: return true
        }
        if case .product = path.last { return false }
        return true
    }
}

struct RootView: View {
    @State private var app = AppModel()
    @State private var cart = CartStore()

    var body: some View {
        ZStack {
            tabContent(.home) {
                NavigationStack(path: $app.homePath) {
                    HomeView()
                        .navigationDestination(for: Route.self, destination: RouteView.init)
                }
            }
            tabContent(.search) {
                NavigationStack(path: $app.searchPath) {
                    SearchView()
                        .navigationDestination(for: Route.self, destination: RouteView.init)
                }
            }
            tabContent(.cart) {
                CartView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if app.showsTabBar {
                TabBar(selection: $app.tab, badge: cart.cart?.totalQuantity ?? 0)
            }
        }
        .background(Color.background)
        .environment(app)
        .environment(cart)
        .alert(
            cart.alertMessage ?? "",
            isPresented: Binding(
                get: { cart.alertMessage != nil },
                set: { if !$0 { cart.alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
    }

    private func tabContent<Content: View>(_ tab: Tab, @ViewBuilder content: () -> Content) -> some View {
        let active = app.tab == tab
        return content()
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .accessibilityHidden(!active)
    }
}

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case let .collection(handle, title):
            CollectionScreen(handle: handle, title: title)
        case let .product(handle):
            ProductScreen(handle: handle)
        }
    }
}

struct TabBar: View {
    @Binding var selection: Tab
    let badge: Int

    var body: some View {
        HStack(spacing: 0) {
            item(.home, "Home", .home, "tab-home")
            item(.search, "Search", .search, "tab-search")
            item(.cart, "Cart", .cart, "tab-cart")
                .overlay(alignment: .top) {
                    if badge > 0 {
                        // Zero-size anchor at the top center; the badge starts 6pt right of center.
                        Color.clear
                            .frame(width: 0, height: 0)
                            .overlay(alignment: .topLeading) {
                                Text("\(badge)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(Capsule().fill(Color.sale))
                                    .fixedSize()
                                    .offset(x: 6, y: 4)
                                    .accessibilityIdentifier("cart-badge")
                                    .allowsHitTesting(false)
                            }
                    }
                }
        }
        .frame(height: 49)
        .background(alignment: .top) {
            Color.background
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Color.border.frame(height: 1)
                }
        }
    }

    private func item(_ tab: Tab, _ label: String, _ icon: IconKind, _ id: String) -> some View {
        let active = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                Icon(kind: icon)
                Text(label)
                    .font(.system(size: 11, weight: active ? .semibold : .medium))
            }
            .foregroundStyle(active ? Color.text : Color.textMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
