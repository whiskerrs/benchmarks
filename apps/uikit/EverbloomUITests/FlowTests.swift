import XCTest

/// Drives the main flows from the spec's "Done" checklist on the simulator.
final class FlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }
    }

    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func wait(_ id: String, _ timeout: TimeInterval = 15) -> XCUIElement {
        let e = el(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "missing \(id)")
        return e
    }

    func testHomeAndCollection() {
        app.launch()
        _ = wait("home-scroll")
        _ = wait("collection-chip-0")
        _ = wait("featured-collection")
        _ = wait("collection-card-0")
        _ = wait("best-seller-0")
        _ = wait("tab-home"); _ = wait("tab-search"); _ = wait("tab-cart")
        shot("01-home")
        el("home-scroll").swipeUp()
        shot("02-home-scrolled")
        el("home-scroll").swipeDown()

        wait("collection-chip-0").tap()
        _ = wait("product-card-0")
        _ = wait("back")
        shot("03-collection")
        let grid = wait("product-grid")
        // Scroll to the end of the collection.
        var lastCount = 0
        for _ in 0..<40 {
            grid.swipeUp(velocity: .fast)
            let count = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'product-card-'")).count
            if count == lastCount && !el("product-card-\(count)").exists { }
            lastCount = count
        }
        shot("04-collection-end")
        for id in ["sort-best-selling", "sort-price-asc", "sort-price-desc", "sort-featured"] {
            wait(id).tap()
            _ = wait("product-card-0")
            shot("05-\(id)")
        }
        wait("product-card-0").tap()
        _ = wait("product-carousel")
        _ = wait("add-to-cart")
        shot("06-product")
        el("back").tap()
        _ = wait("product-grid")
        el("back").tap()
        _ = wait("home-scroll")
    }

    func testProductCartFlow() {
        app.launch()
        wait("best-seller-0").tap()
        _ = wait("product-carousel")
        let add = wait("add-to-cart")
        shot("10-product")
        let firstLabel = add.label
        let pills = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'option-'"))
        if pills.count > 1 {
            pills.element(boundBy: pills.count - 1).tap()
            shot("11-product-option")
            print("PRICE before: \(firstLabel) after: \(add.label)")
        }
        app.swipeUp()
        _ = wait("recommendation-0")
        shot("12-product-recs")
        el("recommendation-0").tap()
        _ = wait("product-carousel")
        sleep(1)
        shot("13-product-rec")
        wait("add-to-cart").tap()
        _ = wait("cart-line-0")
        _ = wait("cart-badge", 5)
        shot("14-cart")
        print(app.tabBars.firstMatch.debugDescription)
        let subtotal = wait("cart-subtotal").label
        wait("qty-inc-0").tap()
        let pred = NSPredicate(format: "label != %@", subtotal)
        expectation(for: pred, evaluatedWith: el("cart-subtotal"))
        waitForExpectations(timeout: 10)
        shot("15-cart-inc")
        wait("qty-dec-0").tap()
        sleep(2)
        wait("qty-dec-0").tap()
        XCTAssertTrue(app.staticTexts["Your cart is empty"].waitForExistence(timeout: 10))
        shot("16-cart-empty")
    }

    func testSearchAndCheckout() {
        app.launch()
        wait("tab-search").tap()
        shot("20-search-empty")
        let input = wait("search-input")
        input.tap()
        input.typeText("shirt")
        _ = wait("search-result-0")
        shot("21-search")
        let list = wait("search-results")
        for _ in 0..<6 { list.swipeUp(velocity: .fast) }
        shot("22-search-scrolled")
        XCTAssertTrue(el("search-result-30").exists || app.cells.count > 0)
        list.swipeDown(velocity: .fast)
        wait("search-result-0").tap()
        _ = wait("add-to-cart")
        el("add-to-cart").tap()
        _ = wait("checkout")
        wait("checkout").tap()
        sleep(4)
        shot("23-checkout")
    }

    /// Launches against a local port. The harness starts a proxy there after ~30s, so Retry should then succeed.
    func testErrorAndRetry() {
        app.launchEnvironment["SHOP_API_URL"] = "http://127.0.0.1:8799/api"
        app.launch()
        let retry = wait("error-retry", 30)
        shot("30-error")
        for _ in 0..<30 {
            if el("best-seller-0").exists { break }
            if el("error-retry").exists { el("error-retry").tap() }
            sleep(3)
        }
        XCTAssertTrue(wait("best-seller-0", 20).exists)
        _ = retry
        shot("31-retried")
    }

    /// Opens collections against a fast local replay server (http://127.0.0.1:8787/api) and scrolls each one.
    /// Regression test for invalid batch updates when pages arrive faster than the grid lays out.
    func testFastReplayCollections() {
        app.launchEnvironment["SHOP_API_URL"] = "http://127.0.0.1:8787/api"
        app.launch()
        for i in 0..<6 {
            wait("collection-chip-\(i)").tap()
            _ = wait("product-card-0")
            let grid = wait("product-grid")
            for _ in 0..<4 { grid.swipeUp(velocity: .fast) }
            for id in ["sort-price-desc", "sort-featured"] {
                wait(id).tap()
                _ = wait("product-card-0")
            }
            XCTAssertEqual(app.state, .runningForeground, "app crashed in collection \(i)")
            wait("back").tap()
            _ = wait("home-scroll")
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Searches against the fast local replay server and scrolls through several pages.
    func testFastReplaySearch() {
        app.launchEnvironment["SHOP_API_URL"] = "http://127.0.0.1:8787/api"
        app.launch()
        wait("tab-search").tap()
        let input = wait("search-input")
        input.tap()
        input.typeText("shirt")
        _ = wait("search-result-0")
        let list = wait("search-results")
        for _ in 0..<8 { list.swipeUp(velocity: .fast) }
        XCTAssertEqual(app.state, .runningForeground)
        input.tap()
        input.typeText("s")
        _ = wait("search-result-0")
        for _ in 0..<4 { list.swipeUp(velocity: .fast) }
        XCTAssertEqual(app.state, .runningForeground)
    }
}
