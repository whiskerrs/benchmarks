# Notes

## Deviations: spec requirements Catalyst cannot meet as shipped

### The native shells are app-owned, not Catalyst's `buildApp:ios` / `buildApp:android`

Catalyst (catalyst-core 1.2.1) builds universal apps as a WebView that loads the web app from a running Catalyst server. Debug builds use the dev server; release builds use `WEBVIEW_CONFIG.url`, which must be a deployed HTTPS site. There is no mode that bundles the HTML into the app: the Android shell's HTML-from-assets path is a commented-out `TODO: Add HTML file workflow`, and the iOS shell always calls `webView.load(ConfigConstants.url)`. That cannot satisfy "no development server … nothing loaded from the network except API and image requests". The shells also cannot read `SHOP_API_URL` from the launch environment, cannot write to the unified log, and log heavily themselves ("Write no other logging"). Changing them would mean modifying Catalyst, which the spec forbids.

So:

- **The web app is pure Catalyst.** It uses the Catalyst project layout, `config/config.json`, `catalyst build` (Vite production build), the SSR `Document` with Catalyst's `Head`/`Body`, `split()` routes, `RouterDataProvider`, and Home's data as a route `clientFetcher` read with `useCurrentRouteData()`. Retry calls Catalyst's `refetch`.
- **`scripts/bundle-web.mjs` packages it.** It runs `catalyst build`, then `catalyst serve` once to capture the server-rendered `/` (the Home skeleton) as `index.html`, and copies that plus `build/client/assets` into both native projects.
- **`ios/` and `android/` are small app-owned WebView hosts**, about 230 lines of Swift and 230 of Java. Each serves the bundle from inside the app package: `everbloom://app/` through a `WKURLSchemeHandler` on iOS, `https://appassets.androidplatform.net/` through `shouldInterceptRequest` on Android. Each also implements the one Catalyst bridge command the app uses, `openInBrowser`, with Catalyst's message format: `webkit.messageHandlers.NativeBridge.postMessage({command, data})` and `window.NativeBridge.openInBrowser(url)`.

### Accessibility identifiers are accessibility labels

WKWebView does not expose any DOM attribute (`id`, `data-testid`, `name`, `title`, …) as an XCUITest `identifier`; I checked this on the iOS 26.5 simulator. XCUITest's identifier lookups (`app.buttons["x"]`, `app.descendants(matching: .any)["x"]`, `matching(identifier:)`) also match the accessibility label, so every benchmark identifier is set as `aria-label`:

- Buttons and cards are `<button aria-label="…">`.
- Scroll containers and cart lines are `role="group" aria-label="…"`.
- `cart-badge` and `cart-subtotal` are `role="text" aria-label="…"`. Their visible text (the count, the amount) is the element's `value`.
- A predicate on `identifier ==` will not find these elements, and VoiceOver reads the identifiers instead of human labels.

`ios/EverbloomUITests` checks that every identifier is found this way.

### Check out opens in SFSafariViewController on iOS and the system browser on Android

Catalyst has no in-app browser; its `useIntent().openInBrowser` opens the system browser. The iOS host implements that command with SFSafariViewController, which is part of the platform, so the checkout opens in-app with no added dependency. The Android host uses an `ACTION_VIEW` intent, which opens the system browser, to avoid adding `androidx.browser`.

## Decisions where the spec was silent

- **Navigation is an in-memory tab/stack navigator** inside the single Catalyst route `/`, not URL routes. Every pushed screen stays mounted (hidden with `visibility: hidden` + `content-visibility: hidden`), so going back or switching tabs keeps each screen's data and scroll position.
- **Pushing and popping have no transition animation**, since there is no platform default for a WebView. Tapping the active tab does nothing. Android's hardware back pops the current stack, then exits.
- **Catalyst's native hooks (`catalyst-core/hooks`, `WebBridge.init`) are not imported.** Importing them puts every hook (camera, video stream, AI) into the startup bundle: about 210 KB more JavaScript, 305 KB to 515 KB. The app sends the one bridge command it needs directly (`src/js/lib/native.js`).
- **API requests go through the native host on iOS and Android** (`WKScriptMessageHandlerWithReply` / `@JavascriptInterface` + `HttpURLConnection`), not WebView `fetch`. This avoids depending on CORS headers from the benchmark's replay server. The request timeout is 30 s. In a plain browser (`npm start`) the app uses `fetch` to mock.shop.
- **GraphQL documents** come from a verbatim copy of `spec/storefront.graphql` (`src/js/api/storefront.graphql`). Each request sends one operation plus the fragments it spreads.
- **Lazy lists:** Catalyst has no list primitive, so the Collection grid and Search results are windowed by hand (`src/js/components/Virtual.js`). Only visible rows plus 2 rows above and below are mounted. Grid rows have a fixed height, with two title lines reserved per card.
- **Collection layout:** the nav bar, description and sort chips stay fixed above the scrolling grid (`product-grid`). The collection title shows right away from the tapped chip or card; the description appears when the first page arrives.
- **Pagination:** a failed next page shows a Retry button (`error-retry`) at the end of the list instead of the full-screen error.
- **Search:** results show the plain price, as in the design. The "N results" line sits above the scrolling list. Pressing the keyboard's Search key dismisses the keyboard. While a new query is loading, a spinner replaces the list.
- **Product:**
  - Option pills wrap onto several lines when they don't fit.
  - If no variant matches every selected option, choosing a pill picks the first available variant with that value.
  - Recommendation cards show the plain price, as in the design.
  - The image dots are buttons that scroll to their image, as in the design.
  - The back button stays fixed in the top-left corner while the page scrolls.
- **Cart:**
  - Operations run one at a time, in order.
  - Quick repeated stepper taps build on the last requested quantity.
  - A network failure on a cart operation shows an alert: "Couldn't update the cart. Check your connection and try again."
  - On `userErrors`, Add to cart shows the alert and stays on Product.
  - The empty state's "Start shopping" button (from the design) switches to the Home tab.
- **Omitted:** the "See all" link next to "Collections" is in the design, but the spec defines no behaviour for it.
- **Error text** uses the spec's straight apostrophe, "Couldn't load products"; the design has ’.
- **iOS:**
  - Light mode is forced.
  - The launch screen is the system's plain white `UILaunchScreen`.
  - The app is iPhone-only, portrait, with deployment target 16.0.
  - `NSAllowsArbitraryLoads` is on, so plain HTTP to LAN addresses works for both the API and images.
  - `NSLocalNetworkUsageDescription` is set because LAN endpoints trigger the Local Network prompt.
  - `window.alert` is shown as a `UIAlertController`.
- **Android:**
  - The endpoint comes from `-PSHOP_API_URL` or the `SHOP_API_URL` environment variable at build time.
  - `usesCleartextTraffic` is on.
  - The content is padded by the system-bar insets because Android 15 enforces edge-to-edge.
  - The host also writes `SHOPBENCH home_ready` to logcat (tag `SHOPBENCH`), once.
- **Log marker:** the iOS host writes `SHOPBENCH home_ready` with `os_log` once per process. It fires when Home first commits its chips and best-seller cards. The app writes no other log lines; the system frameworks' own lines are unchanged.
- **Unused scaffold content removed:** the Catalyst splash screen, offline page and icon.

## Dependencies added

None. `package.json` keeps only the Catalyst scaffold's dependencies: `catalyst-core`, `react`, `react-dom` and `react-router`, plus ESLint as a dev dependency. The iOS host uses only system frameworks (UIKit, WebKit, SafariServices, os). The Android host uses only the platform SDK; the Gradle wrapper files are copied from Catalyst's Android template.

## Verification notes

- **Simulator flows:** `scripts/verify-ios.sh` runs the XCUITest flows on the iOS 26.5 simulator against the Release build. Both tests pass:
  - **testMainFlows:** Home; Collection scrolled to product 84 of 84; all four sorts; Product option switch, carousel swipe and recommendation; add to cart with the badge; stepper up and down to the empty state; Check out; search with a second page.
  - **testErrorAndRetry:** unreachable endpoint, the error state, then Retry once the endpoint is reachable.
- **Network:** the main flow points `SHOP_API_URL` at a local forwarding server (`scripts/forward-server.mjs`) because the build machine's network (a TLS-inspecting proxy) made mock.shop slow and intermittently failing. The default mock.shop endpoint was also checked directly.
- **Closing the in-app browser:** XCUITest taps on SFSafariViewController's Close button were unreliable on the simulator once the checkout page had loaded, so the test relaunches the app after checking that the browser opened.
- **Android emulator** (API 35, arm64): the release APK launches and Home loads. The emulator could not complete TLS through the build machine's proxy, so this check used an APK built with `-PSHOP_API_URL=http://10.0.2.2:8789/api` against the local forwarder. Product images from cdn.shopify.com failed for the same reason. With the default endpoint, the app showed its error state, as expected when TLS fails. Opening a collection and the hardware back button also worked.
- **Clean checkout:** the BUILD.md commands succeed on a copy without `node_modules`, build output or generated `www/`: `npm ci`, `npm run bundle`, the unsigned iOS device build, the simulator build and `./gradlew assembleRelease`.
- **Device build:** not run on hardware (none available). The unsigned `generic/platform=iOS` Release build succeeds and produces an arm64 `.app`.
