import UIKit
import SafariServices

final class CartLineCell: UITableViewCell {
    static let reuseID = "CartLineCell"
    private let thumb = RemoteImageView(cornerRadius: 8)
    private let titleLabel = makeLabel(Theme.font(15, .semibold), lines: 2)
    private let variantLabel = makeLabel(Theme.font(13), Theme.textMuted)
    private let quantityLabel = makeLabel(Theme.font(15, .semibold))
    private let totalLabel = makeLabel(Theme.font(15, .bold))
    let decButton = UIButton(type: .custom)
    let incButton = UIButton(type: .custom)
    var onChange: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        for (button, icon, delta) in [(decButton, Icon.minus, -1), (incButton, Icon.plus, 1)] {
            button.setImage(icon.image(size: 16, lineWidth: 2), for: .normal)
            button.tintColor = Theme.text
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 36).isActive = true
            button.heightAnchor.constraint(equalToConstant: 34).isActive = true
            button.addAction(UIAction { [weak self] _ in self?.onChange?(delta) }, for: .touchUpInside)
        }
        decButton.accessibilityLabel = "Decrease quantity"
        incButton.accessibilityLabel = "Increase quantity"
        quantityLabel.textAlignment = .center
        quantityLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true

        let stepper = UIStackView(arrangedSubviews: [decButton, quantityLabel, incButton])
        stepper.alignment = .center
        stepper.layer.borderColor = Theme.border.cgColor
        stepper.layer.borderWidth = 1
        stepper.layer.cornerRadius = 12
        stepper.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let bottomRow = UIStackView(arrangedSubviews: [stepper, UIView(), totalLabel])
        bottomRow.alignment = .center

        let info = UIStackView(arrangedSubviews: [titleLabel, variantLabel, UIView(), bottomRow])
        info.axis = .vertical
        info.spacing = 4

        let border = UIView()
        border.backgroundColor = Theme.border
        [thumb, info, border].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            thumb.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumb.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            thumb.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            thumb.widthAnchor.constraint(equalToConstant: 80),
            thumb.heightAnchor.constraint(equalToConstant: 107),
            info.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12),
            info.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            info.topAnchor.constraint(equalTo: thumb.topAnchor),
            info.bottomAnchor.constraint(equalTo: thumb.bottomAnchor),
            border.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            border.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            border.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ line: CartLine, index: Int) {
        let merchandise = line.merchandise
        thumb.setURL(sizedImageURL((merchandise.image ?? merchandise.product.featuredImage)?.url, width: 240))
        titleLabel.attributedText = styledText(merchandise.product.title, font: Theme.font(15, .semibold), color: Theme.text, lineHeight: 20)
        variantLabel.text = merchandise.title
        variantLabel.isHidden = merchandise.title == "Default Title"
        quantityLabel.text = "\(line.quantity)"
        totalLabel.text = formatMoney(line.cost.totalAmount)
        accessibilityIdentifier = "cart-line-\(index)"
        decButton.accessibilityIdentifier = "qty-dec-\(index)"
        incButton.accessibilityIdentifier = "qty-inc-\(index)"
    }
}

final class CartViewController: UIViewController, UITableViewDataSource {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let summary = UIView()
    private let subtotalValue = makeLabel(Theme.font(17, .bold))
    private let checkoutButton = PrimaryButton(title: "Check out")
    private var emptyView: MessageStateView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        let header = makeLabel(Theme.font(22, .bold))
        header.text = "Cart"
        header.accessibilityTraits = .header
        let headerContainer = padded(header, 0, 16, 0, 16)
        headerContainer.heightAnchor.constraint(equalToConstant: 44).isActive = true

        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 139
        tableView.register(CartLineCell.self, forCellReuseIdentifier: CartLineCell.reuseID)

        // Summary
        summary.backgroundColor = Theme.background
        let summaryBorder = UIView()
        summaryBorder.backgroundColor = Theme.border
        let subtotalTitle = makeLabel(Theme.font(15))
        subtotalTitle.text = "Subtotal"
        subtotalValue.accessibilityIdentifier = "cart-subtotal"
        let subtotalRow = UIStackView(arrangedSubviews: [subtotalTitle, UIView(), subtotalValue])
        subtotalRow.alignment = .firstBaseline
        let note = makeLabel(Theme.font(13), Theme.textMuted, lines: 0)
        note.text = "Taxes and shipping are calculated at checkout."
        checkoutButton.accessibilityIdentifier = "checkout"
        checkoutButton.addTarget(self, action: #selector(checkout), for: .touchUpInside)
        let summaryStack = UIStackView(arrangedSubviews: [subtotalRow, note, checkoutButton])
        summaryStack.axis = .vertical
        summaryStack.spacing = 12
        summary.pin(summaryStack, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        summaryBorder.translatesAutoresizingMaskIntoConstraints = false
        summary.addSubview(summaryBorder)

        emptyView = MessageStateView(icon: .cart, title: "Your cart is empty", message: "Items you add will appear here.",
                                     buttonTitle: "Start shopping", secondaryButton: false, buttonID: nil)
        emptyView.button?.addAction(UIAction { [weak self] _ in self?.mainTabBar?.showHome() }, for: .touchUpInside)

        [headerContainer, tableView, summary, emptyView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: safe.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: summary.topAnchor),
            summary.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            summary.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            summary.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            summaryBorder.topAnchor.constraint(equalTo: summary.topAnchor),
            summaryBorder.leadingAnchor.constraint(equalTo: summary.leadingAnchor),
            summaryBorder.trailingAnchor.constraint(equalTo: summary.trailingAnchor),
            summaryBorder.heightAnchor.constraint(equalToConstant: 1),
            emptyView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(cartChanged), name: CartStore.didChange, object: nil)
        cartChanged()
    }

    @objc private func cartChanged() {
        let store = CartStore.shared
        let empty = store.lines.isEmpty
        emptyView.isHidden = !empty
        tableView.isHidden = empty
        summary.isHidden = empty
        if let cart = store.cart {
            subtotalValue.text = formatMoney(cart.cost.subtotalAmount)
        }
        tableView.reloadData()
    }

    private func changeQuantity(of line: CartLine, by delta: Int) {
        CartStore.shared.update(lineId: line.id, quantity: line.quantity + delta) { [weak self] message in
            if let message { self?.showAlert(message) }
        }
    }

    @objc private func checkout() {
        guard let raw = CartStore.shared.cart?.checkoutUrl, let url = URL(string: raw) else { return }
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }

    // MARK: Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        CartStore.shared.lines.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CartLineCell.reuseID, for: indexPath) as! CartLineCell
        let line = CartStore.shared.lines[indexPath.row]
        cell.configure(line, index: indexPath.row)
        cell.onChange = { [weak self] delta in self?.changeQuantity(of: line, by: delta) }
        return cell
    }
}
