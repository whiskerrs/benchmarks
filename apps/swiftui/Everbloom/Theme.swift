import SwiftUI
import os

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static let background = Color(hex: 0xFFFFFF)
    static let surface = Color(hex: 0xF4F1EC)
    static let skeleton = Color(hex: 0xEDE9E3)
    static let border = Color(hex: 0xE6E1D9)
    static let text = Color(hex: 0x1C1B19)
    static let textMuted = Color(hex: 0x6E6A63)
    static let textBody = Color(hex: 0x3D3A35)
    static let sale = Color(hex: 0xB4361E)
}

/// Appends the `width` query parameter to an image URL from the API.
func imageURL(_ image: ImageRef?, width: Int) -> URL? {
    guard let raw = image?.url else { return nil }
    let separator = raw.contains("?") ? "&" : "?"
    return URL(string: "\(raw)\(separator)width=\(width)")
}

@MainActor
enum Bench {
    private static var homeReadyLogged = false

    static func homeReady() {
        guard !homeReadyLogged else { return }
        homeReadyLogged = true
        os_log("SHOPBENCH home_ready")
    }
}

// MARK: Icons (paths from the design, 24×24 viewBox)

enum IconKind {
    case home, search, cart, back, plus, minus
}

struct IconShape: Shape {
    let kind: IconKind

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch kind {
        case .home:
            // M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z
            p.move(to: CGPoint(x: 3, y: 10.5))
            p.addLine(to: CGPoint(x: 12, y: 3))
            p.addLine(to: CGPoint(x: 21, y: 10.5))
            p.addLine(to: CGPoint(x: 21, y: 20))
            p.addArc(tangent1End: CGPoint(x: 21, y: 21), tangent2End: CGPoint(x: 20, y: 21), radius: 1)
            p.addLine(to: CGPoint(x: 15, y: 21))
            p.addLine(to: CGPoint(x: 15, y: 15))
            p.addLine(to: CGPoint(x: 9, y: 15))
            p.addLine(to: CGPoint(x: 9, y: 21))
            p.addLine(to: CGPoint(x: 4, y: 21))
            p.addArc(tangent1End: CGPoint(x: 3, y: 21), tangent2End: CGPoint(x: 3, y: 20), radius: 1)
            p.closeSubpath()
        case .search:
            p.addEllipse(in: CGRect(x: 4, y: 4, width: 14, height: 14))
            p.move(to: CGPoint(x: 20, y: 20))
            p.addLine(to: CGPoint(x: 16.5, y: 16.5))
        case .cart:
            p.move(to: CGPoint(x: 6, y: 7))
            p.addLine(to: CGPoint(x: 18, y: 7))
            p.addLine(to: CGPoint(x: 17, y: 20))
            p.addLine(to: CGPoint(x: 7, y: 20))
            p.closeSubpath()
            p.move(to: CGPoint(x: 9, y: 7))
            p.addArc(tangent1End: CGPoint(x: 9, y: 4), tangent2End: CGPoint(x: 12, y: 4), radius: 3)
            p.addArc(tangent1End: CGPoint(x: 15, y: 4), tangent2End: CGPoint(x: 15, y: 7), radius: 3)
        case .back:
            p.move(to: CGPoint(x: 15, y: 5))
            p.addLine(to: CGPoint(x: 8, y: 12))
            p.addLine(to: CGPoint(x: 15, y: 19))
        case .plus:
            p.move(to: CGPoint(x: 12, y: 5))
            p.addLine(to: CGPoint(x: 12, y: 19))
            p.move(to: CGPoint(x: 5, y: 12))
            p.addLine(to: CGPoint(x: 19, y: 12))
        case .minus:
            p.move(to: CGPoint(x: 5, y: 12))
            p.addLine(to: CGPoint(x: 19, y: 12))
        }
        let scale = min(rect.width, rect.height) / 24
        return p.applying(CGAffineTransform(scaleX: scale, y: scale).concatenating(
            CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}

struct Icon: View {
    let kind: IconKind
    var size: CGFloat = 24
    var lineWidth: CGFloat = 1.75

    var body: some View {
        IconShape(kind: kind)
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}
