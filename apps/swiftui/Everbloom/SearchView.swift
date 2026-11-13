import SwiftUI

@MainActor
@Observable
final class SearchModel {
    /// The trimmed query the results belong to (empty = no search).
    private(set) var query = ""
    var results: [ProductCardModel] = []
    var totalCount = 0
    var isLoadingFirstPage = false
    /// True once the first page for `query` has arrived.
    var loaded = false
    var failed = false
    var isLoadingMore = false
    var nearEnd = false

    private var pageInfo: PageInfo?
    private var generation = 0
    private var debounce: Task<Void, Never>?

    func textChanged(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != query else { return }
        query = trimmed
        // Any response for an older query is discarded from here on.
        generation += 1
        debounce?.cancel()
        reset()
        if trimmed.isEmpty { return }
        let gen = generation
        debounce = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, gen == generation else { return }
            search()
        }
    }

    private func reset() {
        results = []
        totalCount = 0
        pageInfo = nil
        failed = false
        isLoadingFirstPage = false
        isLoadingMore = false
        loaded = false
    }

    func search() {
        guard !query.isEmpty else { return }
        generation += 1
        let gen = generation
        let q = query
        reset()
        isLoadingFirstPage = true
        Task {
            do {
                let data = try await API.search(query: q, after: nil)
                guard gen == generation, q == query else { return }
                results = data.search.nodes.compactMap(\.product)
                totalCount = data.search.totalCount
                pageInfo = data.search.pageInfo
                isLoadingFirstPage = false
                loaded = true
            } catch {
                guard gen == generation, q == query else { return }
                isLoadingFirstPage = false
                failed = true
            }
        }
    }

    func loadMore() {
        guard !query.isEmpty, !isLoadingFirstPage, !failed, !isLoadingMore,
              let info = pageInfo, info.hasNextPage, let cursor = info.endCursor else { return }
        isLoadingMore = true
        let gen = generation
        let q = query
        Task {
            do {
                let data = try await API.search(query: q, after: cursor)
                guard gen == generation, q == query else { return }
                results.append(contentsOf: data.search.nodes.compactMap(\.product))
                totalCount = data.search.totalCount
                pageInfo = data.search.pageInfo
                isLoadingMore = false
                if nearEnd { loadMore() }
            } catch {
                guard gen == generation, q == query else { return }
                isLoadingMore = false
            }
        }
    }
}

struct SearchView: View {
    @State private var model = SearchModel()
    @State private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Icon(kind: .search, size: 20)
                    .foregroundStyle(Color.textMuted)
                TextField("", text: $text, prompt: Text("Search products").foregroundStyle(Color.textMuted))
                    .font(.system(size: 16))
                    .foregroundStyle(Color.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityIdentifier("search-input")
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.surface))
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)

            content
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.background)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: text) { _, newValue in model.textChanged(newValue) }
    }

    @ViewBuilder
    private var content: some View {
        if model.query.isEmpty {
            Text("Search across 995 products by name.")
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.vertical, 48)
                .frame(maxWidth: .infinity)
        } else if model.failed {
            ErrorStateView { model.search() }
        } else if !model.loaded {
            LoadingView()
        } else {
            Text("\(model.totalCount) results")
                .font(.system(size: 13))
                .foregroundStyle(Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.results.enumerated()), id: \.offset) { index, product in
                        NavigationLink(value: Route.product(handle: product.handle)) {
                            SearchRow(product: product)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("search-result-\(index)")
                    }
                    if model.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onNearEnd($model.nearEnd) { model.loadMore() }
            .accessibilityIdentifier("search-results")
        }
    }
}

private struct SearchRow: View {
    let product: ProductCardModel

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: imageURL(product.featuredImage, width: 240))
                .frame(width: 64, height: 85)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.system(size: 15))
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color.text)
                PriceView(price: product.price, compareAt: product.compareAt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
