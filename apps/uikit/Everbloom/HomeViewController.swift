import UIKit
import os

final class HomeViewController: UIViewController {
    private static var didLogReady = false

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var errorView: MessageStateView?
    private var loadTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        scrollView.accessibilityIdentifier = "home-scroll"
        scrollView.alwaysBounceVertical = true
        view.pin(scrollView)

        contentStack.axis = .vertical
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        renderSkeleton()
        load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: Loading

    private func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            do {
                let data = try await API.shared.home()
                self?.renderContent(data)
            } catch {
                if Task.isCancelled { return }
                self?.renderError()
            }
        }
    }

    private func resetContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        errorView?.removeFromSuperview()
        errorView = nil
        contentStack.addArrangedSubview(makeHeader())
    }

    private func makeHeader() -> UIView {
        let label = UILabel()
        label.attributedText = styledText("Everbloom", font: Theme.font(22, .bold), color: Theme.text, kern: -0.4)
        label.accessibilityTraits = .header
        let container = padded(label, 0, 16, 0, 16)
        container.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return container
    }

    private func renderSkeleton() {
        resetContent()
        let chips = UIStackView(arrangedSubviews: [52, 110, 96, 80].map { skeletonBlock(width: $0, height: 36, radius: 18) } + [UIView()])
        chips.spacing = 8
        contentStack.addArrangedSubview(padded(chips, 8, 16, 12, 16))
        contentStack.addArrangedSubview(padded(skeletonBlock(width: nil, height: 240, radius: 12), 4, 16, 0, 16))
        let heading = UIStackView(arrangedSubviews: [skeletonBlock(width: 120, height: 18, radius: 4), UIView()])
        contentStack.addArrangedSubview(padded(heading, 28, 16, 12, 16))
        let cards = UIStackView(arrangedSubviews: (0..<3).map { _ in skeletonBlock(width: 140, height: 175, radius: 8) })
        cards.spacing = 12
        let cardsRow = UIView()
        cardsRow.clipsToBounds = true
        cards.translatesAutoresizingMaskIntoConstraints = false
        cardsRow.addSubview(cards)
        NSLayoutConstraint.activate([
            cards.topAnchor.constraint(equalTo: cardsRow.topAnchor),
            cards.bottomAnchor.constraint(equalTo: cardsRow.bottomAnchor),
            cards.leadingAnchor.constraint(equalTo: cardsRow.leadingAnchor, constant: 16),
        ])
        contentStack.addArrangedSubview(cardsRow)
    }

    private func renderError() {
        resetContent()
        let errorView = MessageStateView.loadError { [weak self] in
            self?.renderSkeleton()
            self?.load()
        }
        errorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorView)
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        self.errorView = errorView
    }

    private func renderContent(_ data: HomeData) {
        resetContent()
        let collections = data.collections.nodes

        // Collection chips
        let chipsRow = HorizontalRow(spacing: 8, height: 36)
        let chipStyle = ChipButton.Style(height: 36, horizontalPadding: 14, cornerRadius: 18,
                                         font: Theme.font(14, .medium), textColor: Theme.text,
                                         background: Theme.surface, borderColor: nil)
        for (i, collection) in collections.enumerated() {
            let chip = ChipButton(title: collection.title, style: chipStyle)
            chip.accessibilityIdentifier = "collection-chip-\(i)"
            chip.onTap = { [weak self] in self?.open(collection) }
            chipsRow.stack.addArrangedSubview(chip)
        }
        contentStack.addArrangedSubview(padded(chipsRow, 8, 0, 12, 0))

        // Featured collection banner
        if let featured = collections.first {
            contentStack.addArrangedSubview(padded(makeBanner(featured), 4, 16, 0, 16))
        }

        // Collections carousel
        contentStack.addArrangedSubview(sectionHeading("Collections", top: 28, horizontal: 16))
        let carousel = HorizontalRow(spacing: 12, height: 175 + 8 + 36, alignment: .top)
        for (i, collection) in collections.enumerated() {
            let card = CarouselCard(imageHeight: 175, spacing: 8)
            card.configureCollection(collection)
            card.accessibilityIdentifier = "collection-card-\(i)"
            card.onTap = { [weak self] in self?.open(collection) }
            carousel.stack.addArrangedSubview(card)
        }
        contentStack.addArrangedSubview(carousel)

        // Best sellers grid
        contentStack.addArrangedSubview(sectionHeading("Best sellers", top: 28, horizontal: 16))
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 20
        let products = data.products.nodes
        for rowStart in stride(from: 0, to: products.count, by: 2) {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            row.alignment = .top
            row.distribution = .fillEqually
            for i in rowStart..<min(rowStart + 2, products.count) {
                let product = products[i]
                let card = ProductCardView()
                card.configure(product)
                card.accessibilityIdentifier = "best-seller-\(i)"
                card.onTap = { [weak self] in self?.open(product) }
                row.addArrangedSubview(card)
            }
            if row.arrangedSubviews.count == 1 { row.addArrangedSubview(UIView()) }
            grid.addArrangedSubview(row)
        }
        contentStack.addArrangedSubview(padded(grid, 0, 16, 24, 16))

        view.layoutIfNeeded()
        if !Self.didLogReady {
            Self.didLogReady = true
            os_log("SHOPBENCH home_ready")
        }
    }

    private func sectionHeading(_ title: String, top: CGFloat, horizontal: CGFloat) -> UIView {
        let label = makeLabel(Theme.font(17, .bold))
        label.text = title
        label.accessibilityTraits = .header
        return padded(label, top, horizontal, 12, horizontal)
    }

    private func makeBanner(_ collection: Collection) -> UIView {
        let banner = TapControl()
        banner.accessibilityIdentifier = "featured-collection"
        banner.accessibilityLabel = "Featured collection, \(collection.title), Shop now"
        banner.backgroundColor = Theme.surface
        banner.layer.cornerRadius = 12
        banner.clipsToBounds = true
        banner.heightAnchor.constraint(equalToConstant: 240).isActive = true

        let image = RemoteImageView()
        image.setURL(sizedImageURL(collection.image?.url, width: 1080))
        banner.pin(image)

        let eyebrow = UILabel()
        eyebrow.attributedText = styledText("FEATURED COLLECTION", font: Theme.font(12, .semibold), color: .white, kern: 0.6)
        let title = makeLabel(Theme.font(20, .bold), .white, lines: 2)
        title.text = collection.title
        let cta = makeLabel(Theme.font(14), .white)
        cta.text = "Shop now"
        let textStack = UIStackView(arrangedSubviews: [eyebrow, title, cta])
        textStack.axis = .vertical
        textStack.spacing = 2
        let overlay = UIView()
        overlay.backgroundColor = UIColor(hex: 0x1C1B19, alpha: 0.72)
        overlay.pin(textStack, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        overlay.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: banner.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: banner.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: banner.bottomAnchor),
        ])
        banner.onTap = { [weak self] in self?.open(collection) }
        return banner
    }

    // MARK: Navigation

    private func open(_ collection: Collection) {
        navigationController?.pushViewController(CollectionViewController(handle: collection.handle, title: collection.title), animated: true)
    }

    private func open(_ product: ProductCard) {
        navigationController?.pushViewController(ProductViewController(handle: product.handle), animated: true)
    }
}
