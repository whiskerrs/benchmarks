import UIKit

final class ProductGridCell: UICollectionViewCell {
    static let reuseID = "ProductGridCell"
    let card = ProductCardView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        card.isUserInteractionEnabled = false
        card.isAccessibilityElement = false
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { contentView.alpha = isHighlighted ? 0.6 : 1 }
    }

    func configure(_ product: ProductCard, index: Int) {
        card.configure(product)
        accessibilityIdentifier = "product-card-\(index)"
        accessibilityLabel = card.accessibilityLabel
    }
}

final class LoadingFooterView: UICollectionReusableView {
    static let reuseID = "LoadingFooterView"
    let spinner = makeSpinner()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class CollectionViewController: UIViewController, UICollectionViewDelegate {
    /// Grid item identity: position in the list, scoped to one load generation (one sort order),
    /// so identifiers are unique even if the API repeats a product across pages.
    private struct ItemID: Hashable {
        let generation: Int
        let index: Int
    }

    private let handle: String
    private var sort: CollectionSort = .featured
    private var products: [ProductCard] = []
    private var endCursor: String?
    private var hasNextPage = false
    private var isLoading = false
    private var generation = 0
    private var loadTask: Task<Void, Never>?

    private let descriptionLabel = makeLabel(Theme.font(14), Theme.textMuted, lines: 0)
    private var sortChips: [CollectionSort: ChipButton] = [:]
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, ItemID>!
    private let spinner = makeSpinner()
    private var errorView: MessageStateView?

    private static let selectedSortStyle = ChipButton.Style(height: 32, horizontalPadding: 12, cornerRadius: 16,
                                                            font: Theme.font(13, .semibold), textColor: .white,
                                                            background: Theme.text, borderColor: Theme.text)
    private static let sortStyle = ChipButton.Style(height: 32, horizontalPadding: 12, cornerRadius: 16,
                                                    font: Theme.font(13, .medium), textColor: Theme.text,
                                                    background: Theme.background, borderColor: Theme.border)

    init(handle: String, title: String) {
        self.handle = handle
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        installBackButton()

        let descriptionContainer = padded(descriptionLabel, 4, 16, 0, 16)

        let sortRow = HorizontalRow(spacing: 8, height: 32)
        for option in CollectionSort.allCases {
            let chip = ChipButton(title: option.label, style: option == sort ? Self.selectedSortStyle : Self.sortStyle)
            chip.isChosen = option == sort
            chip.accessibilityIdentifier = option.identifier
            chip.onTap = { [weak self] in self?.select(option) }
            sortRow.stack.addArrangedSubview(chip)
            sortChips[option] = chip
        }
        let sortContainer = padded(sortRow, 12, 0, 12, 0)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.backgroundColor = Theme.background
        collectionView.accessibilityIdentifier = "product-grid"
        collectionView.delegate = self
        collectionView.register(ProductGridCell.self, forCellWithReuseIdentifier: ProductGridCell.reuseID)
        collectionView.register(LoadingFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: LoadingFooterView.reuseID)
        // The diffable data source keeps UICollectionView's item state in sync with `products`.
        // Applying snapshots cannot produce invalid batch updates, however quickly pages arrive.
        dataSource = UICollectionViewDiffableDataSource<Int, ItemID>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ProductGridCell.reuseID, for: indexPath) as! ProductGridCell
            if let self, item.index < self.products.count {
                cell.configure(self.products[item.index], index: item.index)
            }
            return cell
        }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: LoadingFooterView.reuseID, for: indexPath) as! LoadingFooterView
            if let self, self.isLoading, !self.products.isEmpty { footer.spinner.startAnimating() } else { footer.spinner.stopAnimating() }
            return footer
        }

        let header = UIStackView(arrangedSubviews: [descriptionContainer, sortContainer])
        header.axis = .vertical
        header.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        view.addSubview(collectionView)
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: header.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: 48),
        ])

        load(reset: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkLoadMore()
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let width = environment.container.effectiveContentSize.width
            let cardWidth = (width - 32 - 12) / 2
            let height = ProductCardView.height(forWidth: cardWidth)
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(cardWidth), heightDimension: .absolute(height)))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(height)),
                subitems: [item])
            group.interItemSpacing = .fixed(12)
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 20
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
            let footer = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(56)),
                elementKind: UICollectionView.elementKindSectionFooter, alignment: .bottom)
            section.boundarySupplementaryItems = [footer]
            return section
        }
    }

    // MARK: Sorting

    private func select(_ option: CollectionSort) {
        guard option != sort else { return }
        sort = option
        for (key, chip) in sortChips {
            chip.apply(key == option ? Self.selectedSortStyle : Self.sortStyle)
            chip.isChosen = key == option
        }
        load(reset: true)
    }

    // MARK: Loading

    private func load(reset: Bool) {
        if reset {
            loadTask?.cancel()
            generation += 1
            products = []
            endCursor = nil
            hasNextPage = false
            applySnapshot()
            collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: false)
            errorView?.removeFromSuperview()
            errorView = nil
            spinner.startAnimating()
        } else {
            guard hasNextPage, !isLoading else { return }
        }
        isLoading = true
        updateFooter()
        let gen = generation
        let after = endCursor
        let sort = self.sort
        loadTask = Task { [weak self, handle] in
            do {
                let data = try await API.shared.collectionProducts(handle: handle, after: after, sort: sort)
                guard let self, gen == self.generation else { return }
                self.apply(data)
            } catch {
                guard let self, gen == self.generation, !Task.isCancelled else { return }
                self.isLoading = false
                self.spinner.stopAnimating()
                self.updateFooter()
                if self.products.isEmpty { self.showError() }
            }
        }
    }

    private func apply(_ data: CollectionProductsData) {
        isLoading = false
        spinner.stopAnimating()
        guard let collection = data.collection else {
            updateFooter()
            if products.isEmpty { showError() }
            return
        }
        title = collection.title
        if descriptionLabel.text != collection.description {
            descriptionLabel.attributedText = styledText(collection.description, font: Theme.font(14), color: Theme.textMuted, lineHeight: 20)
            descriptionLabel.superview?.isHidden = collection.description.isEmpty
        }
        products.append(contentsOf: collection.products.nodes)
        hasNextPage = collection.products.pageInfo.hasNextPage
        endCursor = collection.products.pageInfo.endCursor
        applySnapshot()
        updateFooter()
        DispatchQueue.main.async { [weak self] in self?.checkLoadMore() }
    }

    /// Publishes the current `products` to the grid.
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, ItemID>()
        snapshot.appendSections([0])
        snapshot.appendItems(products.indices.map { ItemID(generation: generation, index: $0) })
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func showError() {
        let errorView = MessageStateView.loadError { [weak self] in self?.load(reset: true) }
        errorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorView)
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: collectionView.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        self.errorView = errorView
    }

    private func updateFooter() {
        let showing = isLoading && !products.isEmpty
        for case let footer as LoadingFooterView in collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionFooter) {
            showing ? footer.spinner.startAnimating() : footer.spinner.stopAnimating()
        }
    }

    private func checkLoadMore() {
        guard hasNextPage, !isLoading, !products.isEmpty else { return }
        let cv = collectionView!
        guard cv.window != nil else { return }
        // Measure the laid-out content, not a contentSize left over from before the latest update.
        cv.layoutIfNeeded()
        let visibleBottom = cv.contentOffset.y + cv.bounds.height
        if cv.contentSize.height - visibleBottom < cv.bounds.height {
            load(reset: false)
        }
    }

    // MARK: UICollectionView

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath), item.index < products.count else { return }
        let product = products[item.index]
        navigationController?.pushViewController(ProductViewController(handle: product.handle), animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        checkLoadMore()
    }
}
