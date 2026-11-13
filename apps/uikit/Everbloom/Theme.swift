import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

enum Theme {
    static let background = UIColor.white
    static let surface = UIColor(hex: 0xF4F1EC)
    static let skeleton = UIColor(hex: 0xEDE9E3)
    static let border = UIColor(hex: 0xE6E1D9)
    static let text = UIColor(hex: 0x1C1B19)
    static let textMuted = UIColor(hex: 0x6E6A63)
    static let sale = UIColor(hex: 0xB4361E)
    static let bodyText = UIColor(hex: 0x3D3A35)

    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        .systemFont(ofSize: size, weight: weight)
    }
}

/// Formats Storefront money as `$` + amount with two decimals.
func formatMoney(_ money: Money) -> String {
    "$" + String(format: "%.2f", money.value)
}

/// Appends the `width` query parameter to an API image URL.
func sizedImageURL(_ raw: String?, width: Int) -> URL? {
    guard let raw, !raw.isEmpty else { return nil }
    let separator = raw.contains("?") ? "&" : "?"
    return URL(string: raw + separator + "width=\(width)")
}

/// Builds attributed text with an explicit line height.
func styledText(_ string: String, font: UIFont, color: UIColor, lineHeight: CGFloat? = nil,
                kern: CGFloat? = nil, strikethrough: Bool = false, alignment: NSTextAlignment = .natural) -> NSAttributedString {
    var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byTruncatingTail
    if let lineHeight {
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        attrs[.baselineOffset] = (lineHeight - font.lineHeight) / 4
    }
    attrs[.paragraphStyle] = paragraph
    if let kern { attrs[.kern] = kern }
    if strikethrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
    return NSAttributedString(string: string, attributes: attrs)
}

func makeLabel(_ font: UIFont, _ color: UIColor = Theme.text, lines: Int = 1) -> UILabel {
    let label = UILabel()
    label.font = font
    label.textColor = color
    label.numberOfLines = lines
    return label
}

// MARK: - Vector icons (paths from the design SVGs, 24×24 viewBox)

enum Icon {
    case home, search, cart, back, minus, plus, alert

    private func path() -> UIBezierPath {
        let p = UIBezierPath()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        switch self {
        case .home:
            p.move(to: pt(3, 10.5))
            p.addLine(to: pt(12, 3))
            p.addLine(to: pt(21, 10.5))
            p.addLine(to: pt(21, 20))
            p.addArc(withCenter: pt(20, 20), radius: 1, startAngle: 0, endAngle: .pi / 2, clockwise: true)
            p.addLine(to: pt(15, 21))
            p.addLine(to: pt(15, 15))
            p.addLine(to: pt(9, 15))
            p.addLine(to: pt(9, 21))
            p.addLine(to: pt(4, 21))
            p.addArc(withCenter: pt(4, 20), radius: 1, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            p.close()
        case .search:
            p.append(UIBezierPath(arcCenter: pt(11, 11), radius: 7, startAngle: 0, endAngle: 2 * .pi, clockwise: true))
            p.move(to: pt(20, 20))
            p.addLine(to: pt(16.5, 16.5))
        case .cart:
            p.move(to: pt(6, 7))
            p.addLine(to: pt(18, 7))
            p.addLine(to: pt(17, 20))
            p.addLine(to: pt(7, 20))
            p.close()
            p.move(to: pt(9, 7))
            p.addArc(withCenter: pt(12, 7), radius: 3, startAngle: .pi, endAngle: 2 * .pi, clockwise: true)
        case .back:
            p.move(to: pt(15, 5))
            p.addLine(to: pt(8, 12))
            p.addLine(to: pt(15, 19))
        case .minus:
            p.move(to: pt(5, 12))
            p.addLine(to: pt(19, 12))
        case .plus:
            p.move(to: pt(12, 5))
            p.addLine(to: pt(12, 19))
            p.move(to: pt(5, 12))
            p.addLine(to: pt(19, 12))
        case .alert:
            p.append(UIBezierPath(arcCenter: pt(12, 12), radius: 9, startAngle: 0, endAngle: 2 * .pi, clockwise: true))
            p.move(to: pt(12, 7.5))
            p.addLine(to: pt(12, 13))
            p.move(to: pt(12, 16.5))
            p.addLine(to: pt(12.01, 16.5))
        }
        return p
    }

    /// Renders the icon at `size` points. Without a color it is a template image tinted by its view.
    func image(size: CGFloat, lineWidth: CGFloat = 1.75, color: UIColor? = nil) -> UIImage {
        let scale = size / 24
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { _ in
            let p = path()
            p.apply(CGAffineTransform(scaleX: scale, y: scale))
            p.lineWidth = lineWidth * scale
            p.lineCapStyle = .round
            p.lineJoinStyle = .round
            (color ?? .black).setStroke()
            p.stroke()
        }
        return color == nil ? image.withRenderingMode(.alwaysTemplate) : image.withRenderingMode(.alwaysOriginal)
    }
}
