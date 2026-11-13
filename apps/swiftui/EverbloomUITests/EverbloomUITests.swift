import XCTest

/// End-to-end verification of the benchmark flows and accessibility identifiers.
/// Not part of the shipped app.
final class EverbloomUITests: XCTestCase {
    private var app: XCUIApplication!
    private let shotDir = ProcessInfo.processInfo.environment["SHOT_DIR"]

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        if let url = ProcessInfo.processInfo.environment["TEST_SHOP_API_URL"] {
            app.launchEnvironment["SHOP_API_URL"] = url
        }
        app.launch()
    }

    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func wait(_ id: String, _ timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let e = el(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "missing \(id)", file: file, line: line)
        return e
    }

    private func shot(_ name: String) {
        guard let dir = shotDir else { return }
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    private func highest(_ prefix: String, from start: Int) -> Int {
        var m = start
        var probe = start + 1
        var misses = 0
        while misses < 8 {
            if el("\(prefix)\(probe)").exists { m = probe; misses = 0 } else { misses += 1 }
            probe += 1
        }
        return m
    }

    func testHomeAndCollection() {
        for id in ["tab-home", "tab-search", "tab-cart", "home-scroll", "collection-chip-0", "featured-collection", "collection-card-0", "best-seller-0"] {
            _ = wait(id)
        }
        let scroll = el("home-scroll")
        scroll.swipeUp(); scroll.swipeUp()
        _ = wait("best-seller-9")
        shot("home-bottom")
        scroll.swipeDown(); scroll.swipeDown()

        wait("collection-chip-0").tap()
        _ = wait("back")
        _ = wait("product-card-0")
        for id in ["sort-featured", "sort-best-selling", "sort-price-asc", "sort-price-desc", "product-grid"] { _ = wait(id) }
        shot("collection")

        // Scroll to the end of the collection.
        let grid = el("product-grid")
        var maxIndex = 0
        var stable = 0
        while stable < 5 {
            grid.swipeUp(velocity: .fast)
            let m = highest("product-card-", from: maxIndex)
            if m == maxIndex { stable += 1 } else { stable = 0 }
            maxIndex = m
        }
        shot("collection-end")
        print("COLLECTION_LAST_VISIBLE_INDEX \(maxIndex)")
        XCTAssertEqual(maxIndex, 83, "urban-transit-essentials has 84 products")

        for sort in ["sort-price-asc", "sort-price-desc", "sort-best-selling", "sort-featured"] {
            wait(sort).tap()
            _ = wait("product-card-0")
            shot("sort-\(sort)")
        }
        wait("back").tap()
        _ = wait("home-scroll")
    }

    func testProductCartCheckout() {
        wait("best-seller-0").tap()
        _ = wait("product-carousel")
        _ = wait("add-to-cart")
        XCTAssertFalse(el("tab-home").exists, "tab bar hidden on product")
        shot("product")

        let pills = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'option-'"))
        if pills.count > 1 {
            let before = el("add-to-cart").label
            pills.element(boundBy: pills.count - 1).tap()
            print("PRICE before=\(before) after=\(el("add-to-cart").label)")
            shot("product-option")
        }

        let carousel = el("product-carousel")
        carousel.swipeLeft()
        shot("product-carousel-2")

        app.swipeUp(); app.swipeUp()
        let rec = wait("recommendation-0")
        rec.tap()
        _ = wait("add-to-cart")
        sleep(2)
        shot("product-rec")

        wait("add-to-cart").tap()
        _ = wait("cart-line-0")
        _ = wait("cart-badge")
        XCTAssertEqual(el("cart-badge").label, "1")
        shot("cart-1")

        let subtotal0 = wait("cart-subtotal").label
        wait("qty-inc-0").tap()
        let pred = NSPredicate(format: "label != %@", subtotal0)
        expectation(for: pred, evaluatedWith: el("cart-subtotal"))
        waitForExpectations(timeout: 15)
        XCTAssertEqual(el("cart-badge").label, "2")
        shot("cart-2")

        // Checkout opens in-app browser.
        wait("checkout").tap()
        sleep(4)
        shot("checkout")
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 5) { done.tap() } else { app.swipeDown(velocity: .fast) }
        sleep(1)

        // Back on Home, the product stack is preserved.
        wait("tab-home").tap()
        _ = wait("add-to-cart")
        wait("back").tap()
        _ = wait("add-to-cart")
        wait("back").tap()
        _ = wait("home-scroll")

        wait("tab-cart").tap()
        wait("qty-dec-0").tap()
        sleep(1)
        let dec = el("qty-dec-0")
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: dec)
        waitForExpectations(timeout: 15)
        dec.tap()
        XCTAssertTrue(app.staticTexts["Your cart is empty"].waitForExistence(timeout: 15))
        XCTAssertFalse(el("cart-badge").exists)
        shot("cart-empty")
    }

    func testSearch() {
        wait("tab-search").tap()
        XCTAssertTrue(app.staticTexts["Search across 995 products by name."].waitForExistence(timeout: 5))
        let field = wait("search-input")
        field.tap()
        field.typeText("shirt")
        _ = wait("search-results")
        _ = wait("search-result-0")
        shot("search")
        let list = el("search-results")
        var maxIndex = 0
        var stable = 0
        while stable < 5 {
            list.swipeUp(velocity: .fast)
            let m = highest("search-result-", from: maxIndex)
            if m == maxIndex { stable += 1 } else { stable = 0 }
            maxIndex = m
        }
        print("SEARCH_LAST_VISIBLE_INDEX \(maxIndex) total=\(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' results'")).firstMatch.label)")
        XCTAssertGreaterThan(maxIndex, 47)
        shot("search-scrolled")
        wait("search-result-\(maxIndex)").tap()
        _ = wait("add-to-cart")
        wait("back").tap()
        _ = wait("search-results")
    }

    func testErrorState() {
        // Run with TEST_SHOP_API_URL pointing to an endpoint that is down at launch
        // and comes up later; Retry must then load Home.
        let retry = wait("error-retry", 60)
        XCTAssertTrue(app.staticTexts["Couldn't load products"].exists)
        shot("error")
        var tries = 0
        while !el("best-seller-0").exists && tries < 20 {
            if el("error-retry").exists { el("error-retry").tap() }
            _ = el("best-seller-0").waitForExistence(timeout: 5)
            tries += 1
        }
        _ = retry
        XCTAssertTrue(el("best-seller-0").exists, "Retry should load Home once the endpoint is reachable")
        shot("error-retried")
    }
}
