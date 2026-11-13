import Foundation

/// Namespace: "Shopbench.*"
enum ShopbenchFunctions {

    /// Shopbench.Log — writes `message` to the unified log via NSLog, which
    /// reaches Console.app and `log stream` in release builds too.
    class Log: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] {
            let message = parameters["message"] as? String ?? ""
            NSLog("%@", message)
            return BridgeResponse.success(data: [:])
        }
    }
}
