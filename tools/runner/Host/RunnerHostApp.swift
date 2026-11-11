import SwiftUI

// XCUITest bundles need a host app; the benchmark app under test is driven by bundle identifier.
@main
struct RunnerHostApp: App {
    var body: some Scene {
        WindowGroup { Text("ShopBench runner") }
    }
}
