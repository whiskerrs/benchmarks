import UIKit

/// Navigation controller that keeps the swipe-back gesture working with custom back buttons
/// and hidden navigation bars.
final class StackNavigationController: UINavigationController, UIGestureRecognizerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.font: Theme.font(17, .semibold), .foregroundColor: Theme.text]
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = Theme.text
        interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

final class MainTabBarController: UITabBarController {
    private let badgeLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        let home = StackNavigationController(rootViewController: HomeViewController())
        home.tabBarItem = makeItem("Home", .home, id: "tab-home")
        let search = StackNavigationController(rootViewController: SearchViewController())
        search.tabBarItem = makeItem("Search", .search, id: "tab-search")
        let cart = CartViewController()
        cart.tabBarItem = makeItem("Cart", .cart, id: "tab-cart")
        viewControllers = [home, search, cart]

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.background
        appearance.shadowColor = Theme.border
        for layout in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            layout.normal.iconColor = Theme.textMuted
            layout.normal.titleTextAttributes = [.font: Theme.font(11, .medium), .foregroundColor: Theme.textMuted]
            layout.selected.iconColor = Theme.text
            layout.selected.titleTextAttributes = [.font: Theme.font(11, .semibold), .foregroundColor: Theme.text]
        }
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = Theme.text
        tabBar.unselectedItemTintColor = Theme.textMuted

        badgeLabel.font = Theme.font(11, .bold)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center
        badgeLabel.backgroundColor = Theme.sale
        badgeLabel.layer.cornerRadius = 9
        badgeLabel.clipsToBounds = true
        badgeLabel.isUserInteractionEnabled = false
        badgeLabel.isAccessibilityElement = true
        badgeLabel.accessibilityIdentifier = "cart-badge"
        badgeLabel.isHidden = true
        tabBar.addSubview(badgeLabel)

        NotificationCenter.default.addObserver(self, selector: #selector(cartChanged), name: CartStore.didChange, object: nil)
        cartChanged()
    }

    private func makeItem(_ title: String, _ icon: Icon, id: String) -> UITabBarItem {
        let item = UITabBarItem(title: title, image: icon.image(size: 24), selectedImage: icon.image(size: 24))
        item.accessibilityIdentifier = id
        return item
    }

    @objc private func cartChanged() {
        let count = CartStore.shared.totalQuantity
        badgeLabel.text = "\(count)"
        badgeLabel.accessibilityLabel = "\(count) items in cart"
        badgeLabel.isHidden = count == 0
        viewControllers?[2].tabBarItem.accessibilityValue = count > 0 ? "\(count)" : nil
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        positionBadge()
    }

    /// Places the badge over the cart tab: top 4pt, left edge 6pt right of the item's center (per the design).
    private func positionBadge() {
        guard !badgeLabel.isHidden else { return }
        tabBar.layoutIfNeeded()
        var frames: [CGRect] = []
        func collect(_ view: UIView) {
            for sub in view.subviews where !sub.isHidden && sub.alpha > 0 {
                if sub is UIControl, sub !== badgeLabel {
                    let frame = sub.convert(sub.bounds, to: tabBar)
                    if !frames.contains(where: { abs($0.minX - frame.minX) < 1 }) { frames.append(frame) }
                } else {
                    collect(sub)
                }
            }
        }
        collect(tabBar)
        frames.sort { $0.minX < $1.minX }
        let itemFrame: CGRect
        if frames.count >= 3 {
            itemFrame = frames[2]
        } else {
            let width = tabBar.bounds.width / 3
            itemFrame = CGRect(x: width * 2, y: 0, width: width, height: 49)
        }
        let size = badgeLabel.intrinsicContentSize
        let width = max(18, size.width + 10)
        badgeLabel.frame = CGRect(x: itemFrame.midX + 6, y: itemFrame.minY + 4, width: width, height: 18)
        tabBar.bringSubviewToFront(badgeLabel)
    }

    func showCart() {
        selectedIndex = 2
    }

    func showHome() {
        selectedIndex = 0
    }
}

extension UIViewController {
    var mainTabBar: MainTabBarController? {
        var current: UIViewController? = self
        while let vc = current {
            if let tab = vc as? MainTabBarController { return tab }
            current = vc.parent ?? vc.presentingViewController
        }
        return nil
    }
}
