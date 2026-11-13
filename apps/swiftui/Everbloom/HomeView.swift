import SwiftUI

@MainActor
@Observable
final class HomeModel {
    enum Phase {
        case loading
        case failed
        case loaded(HomeData)
    }

    var phase: Phase = .loading
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        load()
    }

    func load() {
        phase = .loading
        Task {
            do {
                phase = .loaded(try await API.home())
            } catch {
                phase = .failed
            }
        }
    }
}

struct HomeView: View {
    @State private var model = HomeModel()

    var body: some View {
        VStack(spacing: 0) {
            Text("Everbloom")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Color.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 44)

            switch model.phase {
            case .loading:
                HomeSkeleton()
            case .failed:
                ErrorStateView { model.load() }
            case let .loaded(data):
                HomeContent(data: data)
                    .onAppear { Bench.homeReady() }
            }
        }
        .background(Color.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { model.start() }
    }
}

private struct HomeContent: View {
    let data: HomeData

    var body: some View {
        let collections = data.collections.nodes
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Collection chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(collections.enumerated()), id: \.element.id) { index, c in
                            NavigationLink(value: Route.collection(handle: c.handle, title: c.title)) {
                                Text(c.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.text)
                                    .lineLimit(1)
                                    .padding(.horizontal, 14)
                                    .frame(height: 36)
                                    .background(Capsule().fill(Color.surface))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("collection-chip-\(index)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }

                // Featured collection
                if let featured = collections.first {
                    NavigationLink(value: Route.collection(handle: featured.handle, title: featured.title)) {
                        RemoteImage(url: imageURL(featured.image, width: 1080))
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .overlay(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Featured collection")
                                        .textCase(.uppercase)
                                        .font(.system(size: 12, weight: .semibold))
                                        .tracking(0.6)
                                    Text(featured.title)
                                        .font(.system(size: 20, weight: .bold))
                                    Text("Shop now")
                                        .font(.system(size: 14))
                                }
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color(hex: 0x1C1B19, opacity: 0.72))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("featured-collection")
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                // Collections carousel
                Text("Collections")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.text)
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
                    .padding(.bottom, 12)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(collections.enumerated()), id: \.element.id) { index, c in
                            NavigationLink(value: Route.collection(handle: c.handle, title: c.title)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    RemoteImage(url: imageURL(c.image, width: 480))
                                        .frame(width: 140, height: 175)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Text(c.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .lineSpacing(2)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .foregroundStyle(Color.text)
                                }
                                .frame(width: 140, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("collection-card-\(index)")
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Best sellers
                Text("Best sellers")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.text)
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
                    .padding(.bottom, 12)
                let products = data.products.nodes
                VStack(spacing: 20) {
                    ForEach(Array(stride(from: 0, to: products.count, by: 2)), id: \.self) { row in
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(row..<min(row + 2, products.count), id: \.self) { index in
                                NavigationLink(value: Route.product(handle: products[index].handle)) {
                                    ProductCard(product: products[index])
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("best-seller-\(index)")
                            }
                            if row + 1 >= products.count {
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .accessibilityIdentifier("home-scroll")
    }
}

private struct HomeSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach([52.0, 110, 96, 80], id: \.self) { w in
                    Capsule().fill(Color.skeleton).frame(width: w, height: 36)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.skeleton)
                .frame(height: 240)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.skeleton)
                .frame(width: 120, height: 18)
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 12)
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.skeleton)
                        .frame(width: 140, height: 175)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityHidden(true)
    }
}
