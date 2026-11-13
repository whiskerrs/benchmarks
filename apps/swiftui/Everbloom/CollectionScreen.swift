import SwiftUI

@MainActor
@Observable
final class CollectionModel {
    let handle: String
    var title: String
    var description = ""
    var sort: SortOption = .featured
    var products: [ProductCardModel] = []
    var isLoadingFirstPage = true
    var failed = false
    var isLoadingMore = false
    var nearEnd = false

    private var pageInfo: PageInfo?
    private var generation = 0
    private var started = false

    init(handle: String, title: String) {
        self.handle = handle
        self.title = title
    }

    func start() {
        guard !started else { return }
        started = true
        reload()
    }

    func select(_ option: SortOption) {
        guard option != sort else { return }
        sort = option
        reload()
    }

    func reload() {
        generation += 1
        let gen = generation
        products = []
        pageInfo = nil
        failed = false
        isLoadingMore = false
        isLoadingFirstPage = true
        let sort = sort
        Task {
            do {
                let data = try await API.collectionProducts(handle: handle, after: nil, sort: sort)
                guard gen == generation else { return }
                guard let collection = data.collection else { throw APIError.noData }
                title = collection.title
                description = collection.description
                products = collection.products.nodes
                pageInfo = collection.products.pageInfo
                isLoadingFirstPage = false
            } catch {
                guard gen == generation else { return }
                isLoadingFirstPage = false
                failed = true
            }
        }
    }

    func loadMore() {
        guard !isLoadingFirstPage, !failed, !isLoadingMore,
              let info = pageInfo, info.hasNextPage, let cursor = info.endCursor else { return }
        isLoadingMore = true
        let gen = generation
        let sort = sort
        Task {
            do {
                let data = try await API.collectionProducts(handle: handle, after: cursor, sort: sort)
                guard gen == generation else { return }
                guard let collection = data.collection else { throw APIError.noData }
                products.append(contentsOf: collection.products.nodes)
                pageInfo = collection.products.pageInfo
                isLoadingMore = false
                if nearEnd { loadMore() }
            } catch {
                guard gen == generation else { return }
                isLoadingMore = false
            }
        }
    }
}

struct CollectionScreen: View {
    @State private var model: CollectionModel

    init(handle: String, title: String) {
        _model = State(initialValue: CollectionModel(handle: handle, title: title))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: model.title)

            if !model.description.isEmpty {
                Text(model.description)
                    .font(.system(size: 14))
                    .lineSpacing(3)
                    .foregroundStyle(Color.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SortOption.allCases) { option in
                        sortChip(option)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .fixedSize(horizontal: false, vertical: true)

            if model.failed {
                ErrorStateView { model.reload() }
            } else if model.isLoadingFirstPage {
                LoadingView()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(Array(model.products.enumerated()), id: \.offset) { index, product in
                            NavigationLink(value: Route.product(handle: product.handle)) {
                                ProductCard(product: product)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("product-card-\(index)")
                        }
                    }
                    .padding(.horizontal, 16)

                    if model.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .contentMargins(.bottom, 16, for: .scrollContent)
                .onNearEnd($model.nearEnd) { model.loadMore() }
                .accessibilityIdentifier("product-grid")
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { model.start() }
    }

    private func sortChip(_ option: SortOption) -> some View {
        let selected = model.sort == option
        return Button {
            model.select(option)
        } label: {
            Text(option.label)
                .font(.system(size: 13, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Color.white : Color.text)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(selected ? Color.text : Color.background))
                .overlay(Capsule().stroke(selected ? Color.text : Color.border, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(option.identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
