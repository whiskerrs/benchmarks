import Foundation
import os

/// What app.ts cannot reach itself: the launch environment's SHOP_API_URL, and
/// the benchmark's one line in the unified log.
final class Shop: ExactModule {
    private static var readyLogged = false

    override func call(_ request: [String: Any]) throws -> [String: Any] {
        switch request["op"] as? String {
        case "env":
            return ["url": ProcessInfo.processInfo.environment["SHOP_API_URL"] ?? ""]
        case "ready":
            if !Shop.readyLogged {
                Shop.readyLogged = true
                os_log("SHOPBENCH home_ready")
            }
            return ["ok": true]
        default:
            throw ExactNativeRefusal("Shop answers env and ready")
        }
    }
}

let exactModule: ExactModule.Type = Shop.self
