import UIKit

// MARK: - Layout helpers

extension UIView {
    func pin(_ child: UIView, insets: UIEdgeInsets = .zero) {
        child.translatesAutoresizingMaskIntoConstraints = false
        addSubview(child)
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            child.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            child.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            child.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
        ])
    }
}

/// Wraps a view with padding.
func padded(_ view: UIView, _ top: CGFloat, _ left: CGFloat, _ bottom: CGFloat, _ right: CGFloat) -> UIView {
    let container = UIView()
    container.pin(view, insets: UIEdgeInsets(top: top, left: left, bottom: bottom, right: right))
    return container
}

/// A horizontally scrolling row with 16pt side padding.
final class HorizontalRow: UIView {
    let scrollView = UIScrollView()
    let stack = UIStackView()

    init(spacing: CGFloat, height: CGFloat, alignment: UIStackView.Alignment = .fill) {
        super.init(frame: .zero)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        pin(scrollView)
        stack.axis = .horizontal
        stack.spacing = spacing
        stack.alignment = alignment
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            heightAnchor.constraint(equalToConstant: height),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Tappable container

/// A control that groups its subviews into one tappable, accessible element.
class TapControl: UIControl {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .button
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    override func addSubview(_ view: UIView) {
        view.isUserInteractionEnabled = false
        super.addSubview(view)
    }

    @objc private func tapped() { onTap?() }
}

// MARK: - Chips and pills

/// Rounded chip / pill with a centered label.
final class ChipButton: TapControl {
    let label = UILabel()

    struct Style {
        var height: CGFloat
        var horizontalPadding: CGFloat
        var cornerRadius: CGFloat
        var font: UIFont
        var textColor: UIColor
        var background: UIColor
        var borderColor: UIColor?
        var borderWidth: CGFloat = 1
        var minWidth: CGFloat = 0
    }

    init(title: String, style: Style) {
        super.init(frame: .zero)
        label.text = title
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        translatesAutoresizingMaskIntoConstraints = false
        heightConstraint = heightAnchor.constraint(equalToConstant: style.height)
        paddingLeading = label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: style.horizontalPadding)
        paddingTrailing = trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: style.horizontalPadding)
        minWidthConstraint = widthAnchor.constraint(greaterThanOrEqualToConstant: style.minWidth)
        NSLayoutConstraint.activate([
            heightConstraint, paddingLeading, paddingTrailing, minWidthConstraint,
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        accessibilityLabel = title
        apply(style)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var heightConstraint: NSLayoutConstraint!
    private var paddingLeading: NSLayoutConstraint!
    private var paddingTrailing: NSLayoutConstraint!
    private var minWidthConstraint: NSLayoutConstraint!

    func apply(_ style: Style) {
        heightConstraint.constant = style.height
        paddingLeading.constant = style.horizontalPadding
        paddingTrailing.constant = style.horizontalPadding
        minWidthConstraint.constant = style.minWidth
        layer.cornerRadius = style.cornerRadius
        backgroundColor = style.background
        label.font = style.font
        label.textColor = style.textColor
        layer.borderColor = style.borderColor?.cgColor
        layer.borderWidth = style.borderColor == nil ? 0 : style.borderWidth
    }

    var isChosen: Bool = false {
        didSet { accessibilityTraits = isChosen ? [.button, .selected] : .button }
    }
}

// MARK: - Buttons

final class PrimaryButton: UIButton {
    init(title: String, height: CGFloat = 52, secondary: Bool = false) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = Theme.font(16, .semibold)
        layer.cornerRadius = 12
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true
        if secondary {
            backgroundColor = Theme.background
            setTitleColor(Theme.text, for: .normal)
            layer.borderWidth = 1
            layer.borderColor = Theme.text.cgColor
        } else {
            backgroundColor = Theme.text
            setTitleColor(.white, for: .normal)
        }
        contentEdgeInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { updateAlpha() }
    }

    override var isEnabled: Bool {
        didSet { updateAlpha() }
    }

    private func updateAlpha() {
        alpha = !isEnabled ? 0.5 : (isHighlighted ? 0.7 : 1)
    }
}

// MARK: - Price

final class PriceView: UIStackView {
    let priceLabel = UILabel()
    let compareLabel = UILabel()
    private let priceFont: UIFont
    private let compareFont: UIFont

    init(priceFont: UIFont = Theme.font(15, .bold), compareFont: UIFont = Theme.font(13)) {
        self.priceFont = priceFont
        self.compareFont = compareFont
        super.init(frame: .zero)
        axis = .horizontal
        spacing = 6
        alignment = .firstBaseline
        addArrangedSubview(priceLabel)
        addArrangedSubview(compareLabel)
        addArrangedSubview(UIView())
        priceLabel.setContentHuggingPriority(.required, for: .horizontal)
        compareLabel.setContentHuggingPriority(.required, for: .horizontal)
    }

    required init(coder: NSCoder) { fatalError() }

    func configure(price: Money, compareAt: Money?) {
        let onSale = (compareAt?.value ?? 0) > price.value
        priceLabel.attributedText = styledText(formatMoney(price), font: priceFont, color: onSale ? Theme.sale : Theme.text)
        if onSale, let compareAt {
            compareLabel.attributedText = styledText(formatMoney(compareAt), font: compareFont, color: Theme.textMuted, strikethrough: true)
            compareLabel.isHidden = false
        } else {
            compareLabel.attributedText = nil
            compareLabel.isHidden = true
        }
    }

    var accessibilityText: String {
        [priceLabel.text, compareLabel.isHidden ? nil : compareLabel.text].compactMap { $0 }.joined(separator: ", ")
    }
}

// MARK: - Product card

/// Image (3:4), title (2 lines max) and price. Used by the Home and Collection grids.
final class ProductCardView: TapControl {
    let imageView = RemoteImageView(cornerRadius: 8)
    let titleLabel = makeLabel(Theme.font(14), lines: 2)
    let priceView = PriceView()

    static func height(forWidth width: CGFloat) -> CGFloat {
        (width * 4 / 3).rounded(.up) + 8 + 36 + 8 + 20
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        [imageView, titleLabel, priceView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 4.0 / 3.0),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            priceView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            priceView.leadingAnchor.constraint(equalTo: leadingAnchor),
            priceView.trailingAnchor.constraint(equalTo: trailingAnchor),
            priceView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ product: ProductCard) {
        imageView.setURL(sizedImageURL(product.featuredImage?.url, width: 480))
        titleLabel.attributedText = styledText(product.title, font: Theme.font(14), color: Theme.text, lineHeight: 18)
        priceView.configure(price: product.price, compareAt: product.compareAt)
        accessibilityLabel = product.title + ", " + priceView.accessibilityText
    }
}

/// 140pt-wide carousel card (collections and recommendations).
final class CarouselCard: TapControl {
    let imageView = RemoteImageView(cornerRadius: 8)
    let titleLabel = makeLabel(Theme.font(14), lines: 2)
    let priceLabel = makeLabel(Theme.font(14, .bold))

    init(imageHeight: CGFloat, spacing: CGFloat) {
        super.init(frame: .zero)
        let stack = UIStackView(arrangedSubviews: [imageView, titleLabel, priceLabel])
        stack.axis = .vertical
        stack.spacing = spacing
        stack.alignment = .fill
        pin(stack)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 140),
            imageView.heightAnchor.constraint(equalToConstant: imageHeight),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configureCollection(_ collection: Collection) {
        imageView.setURL(sizedImageURL(collection.image?.url, width: 480))
        titleLabel.attributedText = styledText(collection.title, font: Theme.font(14, .semibold), color: Theme.text, lineHeight: 18)
        priceLabel.isHidden = true
        accessibilityLabel = collection.title
    }

    func configureProduct(_ product: ProductCard) {
        imageView.setURL(sizedImageURL(product.featuredImage?.url, width: 480))
        titleLabel.attributedText = styledText(product.title, font: Theme.font(14), color: Theme.text, lineHeight: 18)
        priceLabel.text = formatMoney(product.price)
        accessibilityLabel = product.title + ", " + formatMoney(product.price)
    }
}

// MARK: - States

func skeletonBlock(width: CGFloat?, height: CGFloat, radius: CGFloat) -> UIView {
    let view = UIView()
    view.backgroundColor = Theme.skeleton
    view.layer.cornerRadius = radius
    view.translatesAutoresizingMaskIntoConstraints = false
    view.heightAnchor.constraint(equalToConstant: height).isActive = true
    if let width { view.widthAnchor.constraint(equalToConstant: width).isActive = true }
    return view
}

/// Centered icon, title, message and an optional button.
final class MessageStateView: UIView {
    let button: PrimaryButton?

    init(icon: Icon, title: String, message: String, buttonTitle: String?, secondaryButton: Bool, buttonID: String?) {
        if let buttonTitle {
            let b = PrimaryButton(title: buttonTitle, height: 48, secondary: secondaryButton)
            b.accessibilityIdentifier = buttonID
            button = b
        } else {
            button = nil
        }
        super.init(frame: .zero)
        backgroundColor = Theme.background
        let iconView = UIImageView(image: icon.image(size: 48, lineWidth: 1.25, color: Theme.textMuted))
        let titleLabel = makeLabel(Theme.font(17, .bold))
        titleLabel.text = title
        titleLabel.textAlignment = .center
        let messageLabel = makeLabel(Theme.font(15), Theme.textMuted, lines: 0)
        messageLabel.attributedText = styledText(message, font: Theme.font(15), color: Theme.textMuted, lineHeight: 22, alignment: .center)
        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        if let button {
            stack.addArrangedSubview(button)
            stack.setCustomSpacing(20, after: messageLabel)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    static func loadError(retry: @escaping () -> Void) -> MessageStateView {
        let view = MessageStateView(icon: .alert, title: "Couldn't load products",
                                    message: "Check your connection and try again.",
                                    buttonTitle: "Retry", secondaryButton: true, buttonID: "error-retry")
        view.button?.addAction(UIAction { _ in retry() }, for: .touchUpInside)
        return view
    }
}

func makeSpinner() -> UIActivityIndicatorView {
    let spinner = UIActivityIndicatorView(style: .medium)
    spinner.color = Theme.textMuted
    spinner.hidesWhenStopped = true
    spinner.translatesAutoresizingMaskIntoConstraints = false
    return spinner
}

extension UIViewController {
    func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    /// Custom back bar button item carrying the `back` identifier.
    func installBackButton() {
        let item = UIBarButtonItem(image: Icon.back.image(size: 24), style: .plain, target: self, action: #selector(popBack))
        item.accessibilityIdentifier = "back"
        item.accessibilityLabel = "Back"
        navigationItem.leftBarButtonItem = item
    }

    @objc func popBack() {
        navigationController?.popViewController(animated: true)
    }
}
