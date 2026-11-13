import SwiftUI

@MainActor
@Observable
final class ProductModel {
    enum Phase {
        case loading
        case failed
        case loaded(ProductDetail, [ProductCardModel])
    }

    let handle: String
    var phase: Phase = .loading
    var selectedVariantId: String?
    private var started = false

    init(handle: String) {
        self.handle = handle
    }

    func start() {
        guard !started else { return }
        started = true
        load()
    }

    func load() {
        phase = .loading
        Task {
            do {
                let data = try await API.product(handle: handle)
                guard let product = data.product else { throw APIError.noData }
                let variants = product.variants.nodes
                selectedVariantId = (variants.first(where: \.availableForSale) ?? variants.first)?.id
                phase = .loaded(product, data.productRecommendations ?? [])
            } catch {
                phase = .failed
            }
        }
    }

    func select(option name: String, value: String, in product: ProductDetail) {
        let variants = product.variants.nodes
        let current = variants.first { $0.id == selectedVariantId }
        var wanted: [String: String] = [:]
        for option in current?.selectedOptions ?? [] {
            wanted[option.name] = option.value
        }
        wanted[name] = value
        let exact = variants.first { v in
            v.selectedOptions.allSatisfy { wanted[$0.name] == $0.value }
        }
        let fallback = variants.first { $0.value(for: name) == value }
        if let match = exact ?? fallback {
            selectedVariantId = match.id
        }
    }
}

struct ProductScreen: View {
    @State private var model: ProductModel

    init(handle: String) {
        _model = State(initialValue: ProductModel(handle: handle))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch model.phase {
            case .loading:
                LoadingView()
            case .failed:
                ErrorStateView { model.load() }
            case let .loaded(product, recommendations):
                ProductContent(model: model, product: product, recommendations: recommendations)
            }
            RoundBackButton()
                .padding(.leading, 12)
        }
        .background(Color.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { model.start() }
    }
}

private struct RoundBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Icon(kind: .back, size: 22, lineWidth: 1.6)
                .foregroundStyle(Color.text)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.background))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
        .accessibilityIdentifier("back")
    }
}

private struct ProductContent: View {
    let model: ProductModel
    let product: ProductDetail
    let recommendations: [ProductCardModel]

    @Environment(CartStore.self) private var cart
    @Environment(AppModel.self) private var app
    @State private var page = 0
    @State private var adding = false

    private var variant: Variant? {
        product.variants.nodes.first { $0.id == model.selectedVariantId }
    }

    private var visibleOptions: [ProductOption] {
        product.options.filter { option in
            !(option.name == "Title" && option.optionValues.count == 1 && option.optionValues.first?.name == "Default Title")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                carousel

                VStack(alignment: .leading, spacing: 6) {
                    Text(product.title)
                        .font(.system(size: 22, weight: .bold))
                        .lineSpacing(4)
                        .foregroundStyle(Color.text)
                    if let variant {
                        PriceView(price: variant.price, compareAt: variant.compareAtPrice, size: 20, compareSize: 15)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                ForEach(visibleOptions, id: \.name) { option in
                    optionPicker(option)
                        .padding(.top, 24)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.text)
                    Text(product.description)
                        .font(.system(size: 15))
                        .lineSpacing(4)
                        .foregroundStyle(Color.textBody)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)

                if !recommendations.isEmpty {
                    Text("You may also like")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.text)
                        .padding(.horizontal, 16)
                        .padding(.top, 32)
                        .padding(.bottom, 12)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(Array(recommendations.enumerated()), id: \.offset) { index, rec in
                                NavigationLink(value: Route.product(handle: rec.handle)) {
                                    RecommendationCard(product: rec)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("recommendation-\(index)")
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addToCartBar
        }
    }

    private var carousel: some View {
        let images = product.images.nodes
        return Color.surface
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                TabView(selection: $page) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        RemoteImage(url: imageURL(image, width: 1080))
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityIdentifier("product-carousel")
            }
            .overlay(alignment: .bottom) {
                if images.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(images.indices, id: \.self) { index in
                            Button { page = index } label: {
                                Circle()
                                    .fill(index == page ? Color.text : Color(hex: 0x1C1B19, opacity: 0.25))
                                    .frame(width: 8, height: 8)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Show image \(index + 1)")
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            .clipped()
    }

    private func optionPicker(_ option: ProductOption) -> some View {
        let selectedValue = variant?.value(for: option.name) ?? ""
        return VStack(alignment: .leading, spacing: 12) {
            (Text("\(option.name): ").font(.system(size: 15, weight: .semibold)).foregroundColor(Color.text)
                + Text(selectedValue).font(.system(size: 15)).foregroundColor(Color.textMuted))
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(option.optionValues, id: \.name) { value in
                        let selected = value.name == selectedValue
                        Button {
                            model.select(option: option.name, value: value.name, in: product)
                        } label: {
                            Text(value.name)
                                .font(.system(size: 15, weight: selected ? .semibold : .medium))
                                .foregroundStyle(Color.text)
                                .lineLimit(1)
                                .padding(.horizontal, 16)
                                .frame(minWidth: 56, minHeight: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selected ? Color.text : Color.border, lineWidth: selected ? 2 : 1)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("option-\(option.name)-\(value.name)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 1)
            }
        }
    }

    private var addToCartBar: some View {
        let price = variant?.price.formatted ?? ""
        return Button {
            guard let id = variant?.id, !adding else { return }
            adding = true
            Task {
                let ok = await cart.add(variantId: id)
                adding = false
                if ok { app.tab = .cart }
            }
        } label: {
            Text("Add to cart · \(price)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.text.opacity(adding ? 0.5 : 1)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(adding || variant == nil)
        .accessibilityIdentifier("add-to-cart")
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.background.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Color.border.frame(height: 1) }
    }
}

private struct RecommendationCard: View {
    let product: ProductCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: imageURL(product.featuredImage, width: 480))
                .frame(width: 140, height: 187)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(product.title)
                .font(.system(size: 14))
                .lineSpacing(2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.text)
            PriceView(price: product.price, compareAt: product.compareAt, size: 14, compareSize: 13)
        }
        .frame(width: 140, alignment: .leading)
        .contentShape(Rectangle())
    }
}
