import UIKit

final class CarouselImageCell: UICollectionViewCell {
    static let reuseID = "CarouselImageCell"
    let imageView = RemoteImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.pin(imageView)
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class ProductViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private let handle: String
    private var product: ProductDetail?
    private var images: [ImageRef] = []
    private var selectedVariant: Variant?
    private var loadTask: Task<Void, Never>?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let carouselLayout = UICollectionViewFlowLayout()
    private lazy var carousel = UICollectionView(frame: .zero, collectionViewLayout: carouselLayout)
    private let pageControl = UIPageControl()
    private let titleLabel = makeLabel(Theme.font(22, .bold), lines: 0)
    private let priceView = PriceView(priceFont: Theme.font(20, .bold), compareFont: Theme.font(15))
    private var optionLabels: [String: UILabel] = [:]
    private var optionPills: [String: [(value: String, pill: ChipButton)]] = [:]
    private let bottomBar = UIView()
    private let addButton = PrimaryButton(title: "Add to cart")
    private let backButton = UIButton(type: .custom)
    private let spinner = makeSpinner()
    private var errorView: MessageStateView?

    private static let pillStyle = ChipButton.Style(height: 44, horizontalPadding: 16, cornerRadius: 12,
                                                    font: Theme.font(15, .medium), textColor: Theme.text,
                                                    background: Theme.background, borderColor: Theme.border,
                                                    borderWidth: 1, minWidth: 56)
    private static let selectedPillStyle = ChipButton.Style(height: 44, horizontalPadding: 16, cornerRadius: 12,
                                                            font: Theme.font(15, .semibold), textColor: Theme.text,
                                                            background: Theme.background, borderColor: Theme.text,
                                                            borderWidth: 2, minWidth: 56)

    init(handle: String) {
        self.handle = handle
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        // Bottom bar
        bottomBar.backgroundColor = Theme.background
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        let barBorder = UIView()
        barBorder.backgroundColor = Theme.border
        barBorder.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(barBorder)
        bottomBar.addSubview(addButton)
        addButton.accessibilityIdentifier = "add-to-cart"
        addButton.addTarget(self, action: #selector(addToCart), for: .touchUpInside)
        bottomBar.isHidden = true
        let buttonBottom = addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        buttonBottom.priority = .defaultHigh

        // Scroll content
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)
        view.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            barBorder.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            barBorder.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            barBorder.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            barBorder.heightAnchor.constraint(equalToConstant: 1),
            addButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 12),
            addButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            addButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            buttonBottom,
            addButton.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -12),
        ])

        // Back button
        backButton.setImage(Icon.back.image(size: 22), for: .normal)
        backButton.tintColor = Theme.text
        backButton.backgroundColor = Theme.background
        backButton.layer.cornerRadius = 20
        backButton.accessibilityIdentifier = "back"
        backButton.accessibilityLabel = "Back"
        backButton.addTarget(self, action: #selector(popBack), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        view.addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = carousel.bounds.size
        if size.width > 0, carouselLayout.itemSize != size {
            carouselLayout.itemSize = size
            carouselLayout.invalidateLayout()
        }
    }

    // MARK: Loading

    private func load() {
        errorView?.removeFromSuperview()
        errorView = nil
        spinner.startAnimating()
        loadTask?.cancel()
        loadTask = Task { [weak self, handle] in
            do {
                let data = try await API.shared.product(handle: handle)
                guard let self else { return }
                self.spinner.stopAnimating()
                if let product = data.product {
                    self.render(product, recommendations: data.productRecommendations ?? [])
                } else {
                    self.showError()
                }
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.spinner.stopAnimating()
                self.showError()
            }
        }
    }

    private func showError() {
        let errorView = MessageStateView.loadError { [weak self] in self?.load() }
        errorView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(errorView, belowSubview: backButton)
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        self.errorView = errorView
    }

    private func render(_ product: ProductDetail, recommendations: [ProductCard]) {
        self.product = product
        images = Array(product.images.nodes.prefix(10))
        let variants = product.variants.nodes
        selectedVariant = variants.first(where: { $0.availableForSale }) ?? variants.first

        // Image carousel (3:4)
        carouselLayout.scrollDirection = .horizontal
        carouselLayout.minimumLineSpacing = 0
        carouselLayout.minimumInteritemSpacing = 0
        carousel.isPagingEnabled = true
        carousel.showsHorizontalScrollIndicator = false
        carousel.backgroundColor = Theme.surface
        carousel.accessibilityIdentifier = "product-carousel"
        carousel.dataSource = self
        carousel.delegate = self
        carousel.register(CarouselImageCell.self, forCellWithReuseIdentifier: CarouselImageCell.reuseID)
        pageControl.numberOfPages = images.count
        pageControl.hidesForSinglePage = true
        pageControl.currentPageIndicatorTintColor = Theme.text
        pageControl.pageIndicatorTintColor = UIColor(hex: 0x1C1B19, alpha: 0.25)
        pageControl.addTarget(self, action: #selector(pageChanged), for: .valueChanged)
        let carouselContainer = UIView()
        carousel.translatesAutoresizingMaskIntoConstraints = false
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        carouselContainer.addSubview(carousel)
        carouselContainer.addSubview(pageControl)
        NSLayoutConstraint.activate([
            carousel.topAnchor.constraint(equalTo: carouselContainer.topAnchor),
            carousel.leadingAnchor.constraint(equalTo: carouselContainer.leadingAnchor),
            carousel.trailingAnchor.constraint(equalTo: carouselContainer.trailingAnchor),
            carousel.bottomAnchor.constraint(equalTo: carouselContainer.bottomAnchor),
            carousel.heightAnchor.constraint(equalTo: carousel.widthAnchor, multiplier: 4.0 / 3.0),
            pageControl.centerXAnchor.constraint(equalTo: carouselContainer.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: carouselContainer.bottomAnchor, constant: -4),
        ])
        contentStack.addArrangedSubview(carouselContainer)

        // Title and price
        titleLabel.attributedText = styledText(product.title, font: Theme.font(22, .bold), color: Theme.text, lineHeight: 28)
        let titleStack = UIStackView(arrangedSubviews: [titleLabel, priceView])
        titleStack.axis = .vertical
        titleStack.spacing = 6
        contentStack.addArrangedSubview(padded(titleStack, 20, 16, 0, 16))

        // Options
        for option in product.options {
            if option.name == "Title", option.optionValues.count == 1, option.optionValues.first?.name == "Default Title" { continue }
            let label = UILabel()
            optionLabels[option.name] = label
            let row = HorizontalRow(spacing: 8, height: 44)
            var pills: [(String, ChipButton)] = []
            for value in option.optionValues {
                let pill = ChipButton(title: value.name, style: Self.pillStyle)
                pill.accessibilityIdentifier = "option-\(option.name)-\(value.name)"
                pill.onTap = { [weak self] in self?.selectOption(option.name, value.name) }
                row.stack.addArrangedSubview(pill)
                pills.append((value.name, pill))
            }
            optionPills[option.name] = pills
            let block = UIStackView(arrangedSubviews: [padded(label, 0, 16, 0, 16), row])
            block.axis = .vertical
            block.spacing = 12
            contentStack.addArrangedSubview(padded(block, 24, 0, 0, 0))
        }

        // Description
        let descHeading = makeLabel(Theme.font(15, .semibold))
        descHeading.text = "Description"
        let descBody = makeLabel(Theme.font(15), Theme.bodyText, lines: 0)
        descBody.attributedText = styledText(product.description, font: Theme.font(15), color: Theme.bodyText, lineHeight: 22)
        let descStack = UIStackView(arrangedSubviews: [descHeading, descBody])
        descStack.axis = .vertical
        descStack.spacing = 8
        contentStack.addArrangedSubview(padded(descStack, 24, 16, 0, 16))

        // Recommendations
        if !recommendations.isEmpty {
            let heading = makeLabel(Theme.font(17, .bold))
            heading.text = "You may also like"
            contentStack.addArrangedSubview(padded(heading, 32, 16, 12, 16))
            let row = HorizontalRow(spacing: 12, height: 187 + 6 + 36 + 6 + 18, alignment: .top)
            for (i, rec) in recommendations.enumerated() {
                let card = CarouselCard(imageHeight: 187, spacing: 6)
                card.configureProduct(rec)
                card.accessibilityIdentifier = "recommendation-\(i)"
                card.onTap = { [weak self] in
                    self?.navigationController?.pushViewController(ProductViewController(handle: rec.handle), animated: true)
                }
                row.stack.addArrangedSubview(card)
            }
            contentStack.addArrangedSubview(row)
        }
        contentStack.addArrangedSubview(padded(UIView(), 24, 0, 0, 0))

        bottomBar.isHidden = false
        refreshSelection()
    }

    // MARK: Variants

    private func selectOption(_ name: String, _ value: String) {
        guard let product else { return }
        var desired: [String: String] = [:]
        selectedVariant?.selectedOptions.forEach { desired[$0.name] = $0.value }
        desired[name] = value
        let variants = product.variants.nodes
        let match = variants.first { v in v.selectedOptions.allSatisfy { desired[$0.name] == $0.value } }
            ?? variants.first { v in v.selectedOptions.contains { $0.name == name && $0.value == value } }
        guard let match else { return }
        selectedVariant = match
        refreshSelection()
    }

    private func refreshSelection() {
        guard let variant = selectedVariant else {
            addButton.isEnabled = false
            return
        }
        priceView.configure(price: variant.price, compareAt: variant.compareAtPrice)
        addButton.setTitle("Add to cart · \(formatMoney(variant.price))", for: .normal)
        var selected: [String: String] = [:]
        variant.selectedOptions.forEach { selected[$0.name] = $0.value }
        for (name, label) in optionLabels {
            let text = NSMutableAttributedString(attributedString: styledText("\(name): ", font: Theme.font(15, .semibold), color: Theme.text))
            text.append(styledText(selected[name] ?? "", font: Theme.font(15), color: Theme.textMuted))
            label.attributedText = text
        }
        for (name, pills) in optionPills {
            for (value, pill) in pills {
                let isSelected = selected[name] == value
                pill.apply(isSelected ? Self.selectedPillStyle : Self.pillStyle)
                pill.isChosen = isSelected
            }
        }
    }

    // MARK: Cart

    @objc private func addToCart() {
        guard let variant = selectedVariant, !CartStore.shared.isBusy else { return }
        addButton.isEnabled = false
        CartStore.shared.add(variantId: variant.id) { [weak self] message in
            guard let self else { return }
            self.addButton.isEnabled = true
            if let message {
                self.showAlert(message)
            } else {
                self.mainTabBar?.showCart()
            }
        }
    }

    // MARK: Carousel

    @objc private func pageChanged() {
        let x = CGFloat(pageControl.currentPage) * carousel.bounds.width
        carousel.setContentOffset(CGPoint(x: x, y: 0), animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CarouselImageCell.reuseID, for: indexPath) as! CarouselImageCell
        cell.imageView.setURL(sizedImageURL(images[indexPath.item].url, width: 1080))
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = "\(product?.title ?? ""), image \(indexPath.item + 1) of \(images.count)"
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === carousel, carousel.bounds.width > 0 else { return }
        pageControl.currentPage = Int((carousel.contentOffset.x / carousel.bounds.width).rounded())
    }
}
