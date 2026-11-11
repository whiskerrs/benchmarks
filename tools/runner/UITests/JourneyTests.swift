import XCTest
import os

/// Drives the journey in measurement/README.md. Configured through environment variables that
/// xcodebuild forwards with the TEST_RUNNER_ prefix: SHOP_BUNDLE_ID (required) and SHOP_API_URL.
final class JourneyTests: XCTestCase {
    private let logger = Logger(subsystem: "dev.whiskerrs.shopbench.runner", category: "phase")
    private var app: XCUIApplication!

    private let flingDistance: CGFloat = 400
    private let flingVelocity: CGFloat = 3000
    private let flingInterval: TimeInterval = 0.6

    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        let bundleID = try XCTUnwrap(env["SHOP_BUNDLE_ID"], "SHOP_BUNDLE_ID is not set")
        app = XCUIApplication(bundleIdentifier: bundleID)
        if let url = env["SHOP_API_URL"], !url.isEmpty {
            app.launchEnvironment["SHOP_API_URL"] = url
        }
        mark("thermal \(ProcessInfo.processInfo.thermalState.rawValue)")
    }

    /// Run once after install so measured launches never meet the Local Network prompt.
    func testPrepare() {
        app.launch()
        allowLocalNetwork()
        wait("best-seller-0", timeout: 30)
        app.terminate()
    }

    /// Cold launch from the Home Screen icon, for the side-by-side launch video.
    func testTapLaunch() {
        app.terminate()
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons["Everbloom"]
        for _ in 0..<8 where !icon.isHittable {
            springboard.swipeLeft()
            sleep(1)
        }
        do {
            // A fresh install lands next to other apps; dragging it past the last page gives it a
            // page of its own, which goes away again when the app is uninstalled.
            icon.press(forDuration: 1.2)
            let edit = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["ホーム画面を編集", "Edit Home Screen"])).firstMatch
            XCTAssertTrue(edit.waitForExistence(timeout: 5), "no Edit Home Screen menu")
            edit.tap()
            sleep(2)
            let edge = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5))
            icon.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.6, thenDragTo: edge, withVelocity: .slow, thenHoldForDuration: 2.5)
            sleep(2)
            XCUIDevice.shared.press(.home)
            sleep(1)
            for _ in 0..<8 where !icon.isHittable {
                springboard.swipeLeft()
                sleep(1)
            }
        }
        sleep(3)
        mark("tap icon")
        icon.tap()
        wait("best-seller-0", timeout: 30)
        // The screen recording stops shortly after the last UI query, so keep querying.
        for _ in 0..<12 {
            sleep(1)
            _ = element("best-seller-0").exists
        }
    }

    func testJourney() {
        phase("launch") {
            app.launch()
            allowLocalNetwork()
            wait("best-seller-0", timeout: 30)
        }
        phase("idle-after-launch") { sleep(5) }

        phase("scroll-home") {
            let scroll = wait("home-scroll")
            flings(scroll, count: 8, up: true)
            flings(scroll, count: 8, up: false)
        }

        tap("collection-chip-0")
        let grid = wait("product-grid")
        wait("product-card-0")
        for cycle in 1...2 {
            phase("scroll-collection-\(cycle)") {
                flings(grid, count: 20, up: true)
                flings(grid, count: 20, up: false)
            }
        }

        backToTop(grid, until: "sort-price-desc")
        tap("sort-price-desc")
        wait("product-card-0")
        phase("scroll-sorted") {
            flings(grid, count: 3, up: true)
            flings(grid, count: 3, up: false)
        }
        backToTop(grid, until: "product-card-1")

        for n in 0..<5 {
            phase("product-\(n)") {
                tap("product-card-\(n % 2)")
                let carousel = wait("product-carousel")
                swipeLeft(carousel)
                swipeLeft(carousel)
                flings(app.windows.firstMatch, count: 3, up: true)
                tap("recommendation-0")
                wait("product-carousel")
                tapBack()
                wait("product-carousel")
                tapBack()
                wait("product-grid")
            }
        }

        phase("search") {
            tap("tab-search")
            let field = wait("search-input")
            field.tap()
            field.typeText("jacket\n")
            wait("search-result-0")
        }
        phase("scroll-search") {
            let results = wait("search-results")
            flings(results, count: 12, up: true)
            flings(results, count: 12, up: false)
        }
        backToTop(wait("search-results"), until: "search-result-0")

        phase("cart") {
            for n in 0..<3 {
                if n > 0 {
                    tap("tab-search")
                    tap("back")
                }
                tap("search-result-\(n)")
                tap("add-to-cart")
                wait("cart-line-\(n)")
            }
            tap("qty-inc-0")
            tap("qty-inc-0")
            tap("qty-dec-1")
            XCTAssertTrue(element("cart-line-2").waitForNonExistence(timeout: 10), "line not removed")
        }

        phase("return-home") {
            tap("tab-home")
            tap("back")
            wait("best-seller-0")
        }
        phase("idle-after-journey") { sleep(5) }
    }

    // MARK: Helpers

    private func mark(_ message: String) {
        logger.log("SHOPBENCH_RUNNER \(message, privacy: .public)")
    }

    private func phase(_ name: String, _ body: () -> Void) {
        mark("begin \(name)")
        body()
        mark("end \(name)")
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    @discardableResult
    private func wait(_ id: String, timeout: TimeInterval = 15) -> XCUIElement {
        let e = element(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "missing \(id)")
        return e
    }

    private func tap(_ id: String) {
        wait(id).tap()
    }

    /// `up: true` moves the finger up, scrolling the content toward its end. Drags stay above the
    /// software keyboard, which apps may leave open, so they never land on keys.
    private func flings(_ e: XCUIElement, count: Int, up: Bool) {
        for _ in 0..<count {
            var frame = e.frame
            let keyboard = app.keyboards.firstMatch
            if keyboard.exists, keyboard.frame.minY < frame.maxY {
                frame.size.height = max(0, keyboard.frame.minY - frame.minY)
            }
            let distance = min(flingDistance, frame.height * 0.7)
            let x = frame.midX
            let y = up ? frame.minY + frame.height * 0.75 : frame.minY + frame.height * 0.25
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: x, dy: y))
            let end = start.withOffset(CGVector(dx: 0, dy: up ? -distance : distance))
            start.press(forDuration: 0.01, thenDragTo: end, withVelocity: XCUIGestureVelocity(flingVelocity), thenHoldForDuration: 0)
            Thread.sleep(forTimeInterval: flingInterval)
        }
    }

    /// Momentum differs between frameworks, so equal flings down and up need not return to the top.
    private func backToTop(_ e: XCUIElement, until id: String, maxFlings: Int = 15) {
        for _ in 0..<maxFlings where !element(id).isHittable {
            flings(e, count: 1, up: false)
        }
        XCTAssertTrue(element(id).isHittable, "could not scroll back to \(id)")
    }

    /// The design puts Product's back button over the carousel, so it scrolls away with the page.
    private func tapBack() {
        for _ in 0..<6 where !element("back").isHittable {
            flings(app.windows.firstMatch, count: 1, up: false)
        }
        tap("back")
    }

    /// On a device the replay server is on the LAN, so a fresh install first asks for Local Network
    /// access; the app's first requests fail while the prompt is up, so it is relaunched once allowed.
    private func allowLocalNetwork() {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        guard alert.waitForExistence(timeout: 10) else { return }
        for label in ["許可", "Allow"] where alert.buttons[label].exists {
            alert.buttons[label].tap()
            _ = alert.waitForNonExistence(timeout: 5)
            sleep(2)
            app.terminate()
            app.launch()
            return
        }
    }

    private func swipeLeft(_ e: XCUIElement) {
        let start = e.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let end = e.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        start.press(forDuration: 0.01, thenDragTo: end, withVelocity: XCUIGestureVelocity(1500), thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 0.5)
    }
}
