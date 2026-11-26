import XCTest

/// Verification flows for the simulator (not part of the shipped app).
/// Elements are found by their benchmark identifiers, which the web layer exposes
/// as accessibility labels (see src/js/components/ui.js).
final class EverbloomUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        try? FileManager.default.createDirectory(atPath: "/tmp/eb-shots", withIntermediateDirectories: true)
    }

    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    @discardableResult
    private func wait(_ id: String, _ timeout: TimeInterval = 20, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let e = el(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "missing \(id)", file: file, line: line)
        return e
    }

    private func waitGone(_ id: String, _ timeout: TimeInterval = 20) {
        let exp = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: el(id))
        wait(for: [exp], timeout: timeout)
    }

    private func value(_ id: String) -> String { (el(id).value as? String) ?? "" }

    private func waitValue(_ id: String, _ expected: String, _ timeout: TimeInterval = 20,
                           file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if el(id).exists, value(id) == expected { return }
            usleep(200_000)
        }
        XCTFail("\(id) value '\(value(id))' != '\(expected)'", file: file, line: line)
    }

    private func shot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "/tmp/eb-shots/\(name).png"))
    }

    func testMainFlows() throws {
        // Local forwarder started by scripts/verify-ios.sh (also exercises the SHOP_API_URL override).
        app.launchEnvironment["SHOP_API_URL"] = "http://127.0.0.1:8789/api"
        app.launch()

        // Home
        wait("home-scroll")
        wait("collection-chip-0", 30)
        wait("best-seller-0")
        wait("featured-collection")
        wait("collection-card-0")
        for id in ["tab-home", "tab-search", "tab-cart"] { XCTAssertTrue(el(id).exists, id) }
        XCTAssertFalse(el("cart-badge").exists)
        shot("01-home")

        // Collection: scroll to the end (84 products = 4 pages of 24)
        el("collection-chip-0").tap()
        let grid = wait("product-grid")
        wait("product-card-0")
        wait("back")
        shot("02-collection")
        var reachedEnd = false
        for _ in 0..<60 {
            grid.swipeUp(velocity: .fast)
            if el("product-card-83").exists { reachedEnd = true; break }
        }
        XCTAssertTrue(reachedEnd, "did not reach product-card-83")
        XCTAssertFalse(el("product-card-0").exists, "grid is not windowed")
        shot("03-collection-end")

        // Sorts
        for id in ["sort-best-selling", "sort-price-asc", "sort-price-desc", "sort-featured"] {
            el(id).tap()
            wait("product-card-0")
            shot("04-\(id)")
        }

        // Product
        el("sort-price-desc").tap()
        sleep(1)
        wait("product-card-0").tap()
        wait("product-carousel")
        wait("add-to-cart")
        XCTAssertFalse(el("tab-home").exists, "tab bar should be hidden on Product")
        shot("05-product")
        let pills = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'option-'"))
        XCTAssertGreaterThan(pills.count, 1)
        pills.element(boundBy: pills.count - 1).tap()
        shot("06-product-option")
        el("product-carousel").swipeLeft()
        shot("07-product-carousel-2")
        app.swipeUp()
        wait("recommendation-0").tap()
        sleep(2)
        wait("add-to-cart")
        shot("08-recommendation")
        el("back").tap()
        wait("add-to-cart")

        // Add to cart -> Cart tab with badge
        el("add-to-cart").tap()
        wait("cart-line-0")
        waitValue("cart-badge", "1")
        let subtotal1 = value("cart-subtotal")
        shot("09-cart")
        el("qty-inc-0").tap()
        waitValue("cart-badge", "2")
        XCTAssertNotEqual(value("cart-subtotal"), subtotal1)
        shot("10-cart-qty2")
        el("qty-dec-0").tap()
        waitValue("cart-badge", "1")
        el("qty-dec-0").tap()
        waitGone("cart-line-0")
        XCTAssertTrue(app.staticTexts["Your cart is empty"].waitForExistence(timeout: 10))
        XCTAssertFalse(el("cart-badge").exists)
        shot("11-cart-empty")

        // Home tab kept its stack (Product on top)
        el("tab-home").tap()
        wait("add-to-cart").tap()
        wait("cart-line-0")

        // Check out opens the checkout URL in the in-app browser
        el("checkout").tap()
        sleep(5)
        shot("12-checkout")
        XCTAssertTrue(app.buttons["Close"].firstMatch.exists, "in-app browser not shown")
        app.buttons["Close"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        if !el("tab-search").waitForExistence(timeout: 5) {
            // XCUITest taps on SFSafariViewController's Close button are unreliable on the
            // iOS 26.5 simulator once the page has loaded; restart to continue the flow.
            app.terminate()
            app.launch()
        }

        // Search
        wait("tab-search").tap()
        let input = wait("search-input")
        XCTAssertTrue(app.staticTexts["Search across 995 products by name."].exists)
        input.tap()
        input.typeText("shirt\n")
        wait("search-result-0")
        wait("search-results")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' results'")).firstMatch.waitForExistence(timeout: 10))
        shot("13-search")
        let results = el("search-results")
        var more = false
        for _ in 0..<20 {
            results.swipeUp(velocity: .fast)
            if el("search-result-30").exists { more = true; break }
        }
        XCTAssertTrue(more, "search did not load a second page")
        shot("14-search-scrolled")
        el("search-result-30").tap()
        wait("add-to-cart")
        el("back").tap()
        wait("search-results")
    }

    /// Unreachable endpoint shows the error state; Retry recovers once it is reachable.
    /// scripts/verify-ios.sh starts a forwarding server when /tmp/eb-need-server appears.
    func testErrorAndRetry() throws {
        try? FileManager.default.removeItem(atPath: "/tmp/eb-need-server")
        app.launchEnvironment["SHOP_API_URL"] = "http://127.0.0.1:8788/api"
        app.launch()
        wait("error-retry", 30)
        XCTAssertTrue(app.staticTexts["Couldn't load products"].exists)
        shot("20-error")
        FileManager.default.createFile(atPath: "/tmp/eb-need-server", contents: Data())
        sleep(6)
        el("error-retry").tap()
        wait("collection-chip-0", 30)
        wait("best-seller-0")
        shot("21-retry-ok")
    }
}
