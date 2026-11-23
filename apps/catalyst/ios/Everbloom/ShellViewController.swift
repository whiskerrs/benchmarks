import UIKit
import WebKit
import SafariServices
import os

/// Hosts the Catalyst web build (bundled under `www/`) in a WKWebView.
///
/// - `everbloom://app/...` is served from the app bundle, so nothing but API and
///   image requests touch the network.
/// - `shopApi` (message with reply) sends the Storefront GraphQL POST natively, to the
///   endpoint from the `SHOP_API_URL` environment variable or the default mock.shop URL.
/// - `NativeBridge` implements the one Catalyst bridge command the app uses
///   (`openInBrowser`, from `useIntent()`).
/// - `shopbench` writes the `SHOPBENCH home_ready` marker to the unified log.
final class ShellViewController: UIViewController {
    static let scheme = "everbloom"
    static let startURL = URL(string: "everbloom://app/")!

    private static let defaultAPIURL = URL(string: "https://apparel-large-catalog.mock.shop/api")!

    private static let apiURL: URL = {
        let value = ProcessInfo.processInfo.environment["SHOP_API_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !value.isEmpty, let url = URL(string: value) { return url }
        return defaultAPIURL
    }()

    private static var homeReadyLogged = false

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    private var webView: WKWebView!

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: Self.scheme)
        config.allowsInlineMediaPlayback = true
        config.suppressesIncrementalRendering = false

        let controller = config.userContentController
        controller.addScriptMessageHandler(self, contentWorld: .page, name: "shopApi")
        controller.add(WeakMessageHandler(self), name: "NativeBridge")
        controller.add(WeakMessageHandler(self), name: "shopbench")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.scrollView.isScrollEnabled = false
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif
        self.webView = webView
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: Self.startURL))
    }

    // MARK: - API proxy

    fileprivate func sendGraphQL(body: String, reply: @escaping (Any?, String?) -> Void) {
        var request = URLRequest(url: Self.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    reply(nil, error.localizedDescription)
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                reply(["status": status, "body": text], nil)
            }
        }.resume()
    }

    // MARK: - Bridge commands

    fileprivate func handleBridge(_ message: WKScriptMessage) {
        switch message.name {
        case "shopbench":
            if (message.body as? String) == "home_ready", !Self.homeReadyLogged {
                Self.homeReadyLogged = true
                os_log("SHOPBENCH home_ready")
            }
        case "NativeBridge":
            guard let payload = message.body as? [String: Any],
                  let command = payload["command"] as? String else { return }
            if command == "openInBrowser" {
                openInBrowser(payload["data"] as? String)
            }
        default:
            break
        }
    }

    /// Catalyst's `openInBrowser`. Opens in an in-app browser (SFSafariViewController).
    private func openInBrowser(_ value: String?) {
        guard let value, let url = URL(string: value),
              url.scheme == "https" || url.scheme == "http" else { return }
        let safari = SFSafariViewController(url: url)
        safari.dismissButtonStyle = .close
        present(safari, animated: true)
    }
}

// MARK: - Script message handlers

extension ShellViewController: WKScriptMessageHandlerWithReply {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping (Any?, String?) -> Void
    ) {
        guard let body = message.body as? String else {
            replyHandler(nil, "Invalid request body")
            return
        }
        sendGraphQL(body: body, reply: replyHandler)
    }
}

/// Breaks the retain cycle between WKUserContentController and the view controller.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var owner: ShellViewController?

    init(_ owner: ShellViewController) { self.owner = owner }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.handleBridge(message)
    }
}

// MARK: - Navigation

extension ShellViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // The app is a single page; only frames from the bundle may navigate.
        decisionHandler(navigationAction.request.url?.scheme == Self.scheme ? .allow : .cancel)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.load(URLRequest(url: Self.startURL))
    }
}

// MARK: - JavaScript alerts

extension ShellViewController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }
}

// MARK: - Bundled web assets

/// Serves `everbloom://app/<path>` from the `www` folder in the app bundle.
/// Paths without a matching file fall back to `index.html` (single-page app).
private final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root: URL = Bundle.main.resourceURL!.appendingPathComponent("www", isDirectory: true)

    private static let mimeTypes: [String: String] = [
        "html": "text/html; charset=utf-8",
        "js": "text/javascript; charset=utf-8",
        "mjs": "text/javascript; charset=utf-8",
        "css": "text/css; charset=utf-8",
        "json": "application/json; charset=utf-8",
        "svg": "image/svg+xml",
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "webp": "image/webp",
        "ico": "image/x-icon",
        "woff2": "font/woff2",
    ]

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        var path = url.path
        if path.hasPrefix("/") { path.removeFirst() }
        var fileURL = root.appendingPathComponent(path).standardizedFileURL
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
        if path.isEmpty || !exists || isDirectory.boolValue || !fileURL.path.hasPrefix(root.path) {
            if !path.isEmpty, !(url.pathExtension.isEmpty) {
                respond(task, url: url, status: 404, mime: "text/plain", data: Data())
                return
            }
            fileURL = root.appendingPathComponent("index.html")
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            respond(task, url: url, status: 404, mime: "text/plain", data: Data())
            return
        }
        let mime = Self.mimeTypes[fileURL.pathExtension.lowercased()] ?? "application/octet-stream"
        respond(task, url: url, status: 200, mime: mime, data: data)
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private func respond(_ task: WKURLSchemeTask, url: URL, status: Int, mime: String, data: Data) {
        let headers = [
            "Content-Type": mime,
            "Content-Length": String(data.count),
            "Cache-Control": "no-cache",
        ]
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }
}
