import UIKit

final class SearchResultCell: UITableViewCell {
    static let reuseID = "SearchResultCell"
    private let thumb = RemoteImageView(cornerRadius: 8)
    private let titleLabel = makeLabel(Theme.font(15), lines: 2)
    private let priceView = PriceView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        let textStack = UIStackView(arrangedSubviews: [titleLabel, priceView])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumb)
        contentView.addSubview(textStack)
        NSLayoutConstraint.activate([
            thumb.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumb.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            thumb.widthAnchor.constraint(equalToConstant: 64),
            thumb.heightAnchor.constraint(equalToConstant: 85),
            textStack.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: thumb.centerYAnchor),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError() }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        contentView.alpha = highlighted ? 0.6 : 1
    }

    func configure(_ product: ProductCard, index: Int) {
        thumb.setURL(sizedImageURL(product.featuredImage?.url, width: 240))
        titleLabel.attributedText = styledText(product.title, font: Theme.font(15), color: Theme.text, lineHeight: 20)
        priceView.configure(price: product.price, compareAt: product.compareAt)
        accessibilityIdentifier = "search-result-\(index)"
        accessibilityLabel = product.title + ", " + priceView.accessibilityText
    }
}

final class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    private let field = UITextField()
    private let countLabel = makeLabel(Theme.font(13), Theme.textMuted)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = makeLabel(Theme.font(15), Theme.textMuted, lines: 0)
    private let spinner = makeSpinner()
    private let footerSpinner = makeSpinner()
    private var errorView: MessageStateView?

    private var query = ""
    private var results: [ProductCard] = []
    private var endCursor: String?
    private var hasNextPage = false
    private var isLoading = false
    private var generation = 0
    private var debounce: DispatchWorkItem?
    private var loadTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        // Search field
        let fieldBox = UIView()
        fieldBox.backgroundColor = Theme.surface
        fieldBox.layer.cornerRadius = 12
        let icon = UIImageView(image: Icon.search.image(size: 20))
        icon.tintColor = Theme.textMuted
        field.font = Theme.font(16)
        field.textColor = Theme.text
        field.attributedPlaceholder = NSAttributedString(string: "Search products", attributes: [.foregroundColor: Theme.textMuted, .font: Theme.font(16)])
        field.accessibilityIdentifier = "search-input"
        field.accessibilityLabel = "Search products"
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .search
        field.clearButtonMode = .whileEditing
        field.delegate = self
        field.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        let fieldStack = UIStackView(arrangedSubviews: [icon, field])
        fieldStack.spacing = 8
        fieldStack.alignment = .center
        icon.setContentHuggingPriority(.required, for: .horizontal)
        fieldBox.pin(fieldStack, insets: UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12))
        fieldBox.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let fieldContainer = padded(fieldBox, 4, 16, 12, 16)

        let countContainer = padded(countLabel, 4, 16, 8, 16)

        tableView.accessibilityIdentifier = "search-results"
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.rowHeight = 101
        tableView.keyboardDismissMode = .onDrag
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseID)
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 56))
        footer.addSubview(footerSpinner)
        NSLayoutConstraint.activate([
            footerSpinner.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            footerSpinner.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
        ])
        tableView.tableFooterView = footer

        emptyLabel.attributedText = styledText("Search across 995 products by name.", font: Theme.font(15), color: Theme.textMuted, lineHeight: 22, alignment: .center)
        let emptyContainer = padded(emptyLabel, 48, 32, 48, 32)

        let column = UIStackView(arrangedSubviews: [fieldContainer, countContainer, emptyContainer, tableView])
        column.axis = .vertical
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            column.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            column.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: fieldContainer.bottomAnchor, constant: 48),
        ])
        emptyContainer.setContentHuggingPriority(.required, for: .vertical)
        renderEmptyState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: Query handling

    @objc private func textChanged() {
        debounce?.cancel()
        let text = (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            query = ""
            generation += 1
            loadTask?.cancel()
            isLoading = false
            renderEmptyState()
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.start(text) }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func renderEmptyState() {
        results = []
        tableView.reloadData()
        tableView.isHidden = true
        countLabel.superview?.isHidden = true
        emptyLabel.superview?.isHidden = false
        spinner.stopAnimating()
        footerSpinner.stopAnimating()
        errorView?.removeFromSuperview()
        errorView = nil
    }

    private func start(_ text: String) {
        if text == query, errorView == nil { return }
        query = text
        generation += 1
        loadTask?.cancel()
        results = []
        endCursor = nil
        hasNextPage = false
        isLoading = false
        tableView.reloadData()
        tableView.isHidden = false
        emptyLabel.superview?.isHidden = true
        countLabel.superview?.isHidden = true
        errorView?.removeFromSuperview()
        errorView = nil
        spinner.startAnimating()
        loadPage()
    }

    private func loadPage() {
        guard !isLoading else { return }
        isLoading = true
        if !results.isEmpty { footerSpinner.startAnimating() }
        let gen = generation
        let query = self.query
        let after = endCursor
        loadTask = Task { [weak self] in
            do {
                let data = try await API.shared.search(query: query, after: after)
                guard let self, gen == self.generation, query == self.query else { return }
                self.apply(data.search)
            } catch {
                guard let self, gen == self.generation, query == self.query, !Task.isCancelled else { return }
                self.isLoading = false
                self.spinner.stopAnimating()
                self.footerSpinner.stopAnimating()
                if self.results.isEmpty { self.showError() }
            }
        }
    }

    private func apply(_ search: SearchConnection) {
        isLoading = false
        spinner.stopAnimating()
        footerSpinner.stopAnimating()
        countLabel.text = "\(search.totalCount) results"
        countLabel.superview?.isHidden = false
        let start = results.count
        // Ask the table for its own row count before changing the model, so an insert is only used
        // when the table's state matches `results` (a reload may still be pending).
        let shownRows = tableView.numberOfRows(inSection: 0)
        results.append(contentsOf: search.nodes)
        hasNextPage = search.pageInfo.hasNextPage
        endCursor = search.pageInfo.endCursor
        if start == 0 {
            tableView.reloadData()
            tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
        } else if shownRows != start {
            tableView.reloadData()
        } else {
            tableView.insertRows(at: (start..<results.count).map { IndexPath(row: $0, section: 0) }, with: .none)
        }
        DispatchQueue.main.async { [weak self] in self?.checkLoadMore() }
    }

    private func showError() {
        tableView.isHidden = true
        let errorView = MessageStateView.loadError { [weak self] in
            guard let self else { return }
            self.start(self.query)
        }
        errorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorView)
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        self.errorView = errorView
    }

    private func checkLoadMore() {
        guard hasNextPage, !isLoading, !results.isEmpty, tableView.window != nil else { return }
        // Measure the laid-out content, not a contentSize left over from before the latest update.
        tableView.layoutIfNeeded()
        let visibleBottom = tableView.contentOffset.y + tableView.bounds.height
        if tableView.contentSize.height - visibleBottom < tableView.bounds.height {
            loadPage()
        }
    }

    // MARK: Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultCell.reuseID, for: indexPath) as! SearchResultCell
        cell.configure(results[indexPath.row], index: indexPath.row)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        field.resignFirstResponder()
        let product = results[indexPath.row]
        navigationController?.pushViewController(ProductViewController(handle: product.handle), animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        checkLoadMore()
    }
}
