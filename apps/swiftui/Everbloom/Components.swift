import SwiftUI

/// Aspect-fill image that shows the `surface` color until it has loaded.
struct RemoteImage: View {
    let url: URL?

    var body: some View {
        Color.surface
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.surface
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipped()
    }
}

struct PriceView: View {
    let price: Money
    let compareAt: Money?
    var size: CGFloat = 15
    var compareSize: CGFloat = 13

    var body: some View {
        let onSale = (compareAt?.value ?? 0) > price.value
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(price.formatted)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(onSale ? Color.sale : Color.text)
            if onSale, let compareAt {
                Text(compareAt.formatted)
                    .font(.system(size: compareSize))
                    .strikethrough()
                    .foregroundStyle(Color.textMuted)
            }
        }
    }
}

/// Product card used by the Home best sellers grid and the Collection grid.
struct ProductCard: View {
    let product: ProductCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay { RemoteImage(url: imageURL(product.featuredImage, width: 480)) }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(product.title)
                .font(.system(size: 14))
                .lineSpacing(2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.text)
            PriceView(price: product.price, compareAt: product.compareAt)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }
}

struct ErrorStateView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Couldn't load products")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.text)
            Text("Check your connection and try again.")
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(Color.textMuted)
            Button(action: retry) {
                Text("Retry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.text)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.text, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .accessibilityIdentifier("error-retry")
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 44pt back button used in navigation headers.
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Icon(kind: .back)
                .foregroundStyle(Color.text)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
        .accessibilityIdentifier("back")
    }
}

/// Navigation header: back button, centered title.
struct NavHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            BackButton()
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
    }
}

extension View {
    /// Calls `action` when the user scrolls within one screen height of the end.
    func onNearEnd(_ nearEnd: Binding<Bool>, action: @escaping () -> Void) -> some View {
        onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentSize.height - geo.visibleRect.maxY < geo.containerSize.height
        } action: { _, isNear in
            nearEnd.wrappedValue = isNear
            if isNear { action() }
        }
    }
}
