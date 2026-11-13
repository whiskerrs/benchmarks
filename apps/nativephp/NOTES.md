# Notes

Everbloom built with NativePHP for Mobile v4 ("SuperNative"): the UI is native SwiftUI (iOS) / Jetpack Compose
(Android) rendered from EDGE Blade elements, driven by PHP running on the device. No web view is used.

## Architecture

- `app/NativeComponents/Shell.php` is the only native screen (`routes/mobile.php`). It owns the three tab stacks,
  the per-screen state, the in-memory cart and all handlers. Views live in `resources/views/native/`
  (`shell.blade.php`, `screens/*`, `partials/*`).
- `app/Shop/Storefront.php` sends GraphQL as plain HTTP (Laravel's HTTP client, `POST` JSON with
  `operationName`, `query`, `variables`). Each request carries the operation exactly as written in
  `resources/graphql/storefront.graphql` (a verbatim copy of `spec/storefront.graphql`) plus only the fragments it
  spreads (an unused fragment would make the document invalid).
- `app/Shop/Format.php` formats money (`$` + two decimals, no thousands separator) and appends `width` to image URLs.
- Requests run on NativePHP's background PHP lane (`AsyncTask`), so the UI never waits on the network. Responses are
  dropped if the screen has been closed or a newer request for it was sent (sort change, new search query, etc.).
- `packages/shopbench-native` is a small app-local NativePHP plugin (see Dependencies).

## Decisions where the spec is silent

- **Why one screen.** NativePHP's router has a single navigation stack. Its native tab bar keeps each tab's
  SwiftUI views, but a tab tap *replaces* the PHP screen, so a tab's screens lose their state when you switch back.
  Its tab bar also exposes no accessibility identifiers, and on iOS it is always hidden on pushed screens (the
  Collection design shows it). So `Shell` keeps the three stacks itself and renders the top screen of the active
  tab, plus a tab bar drawn with EDGE elements. Only the visible screen is rendered, so identifiers such as `back`
  or `recommendation-0` are never duplicated by hidden screens. Screens further down a stack keep their data.
  Because only the top screen is rendered, a list underneath is rebuilt when you go back; the row you tapped is
  scrolled back to the top (`auto-scroll-to`), so you return to where you were in a collection or search.
- **Consequences:** pushes and pops use no slide animation, and there is no iOS edge-swipe-back gesture. The spec
  allows no animations beyond the framework default, and the framework's default for swapping content within one
  screen is none. Android's hardware back pops the active tab's stack, and exits the app at a tab root.
- Tapping the tab you are already on does nothing (it does not pop to the root).
- **First Home load.** `Shell` is `#[Lazy]`: NativePHP paints the placeholder (the Home skeleton and tab bar)
  before `mount()` runs. `mount()` then sends the first `Home` request inline instead of on the background lane,
  because that lane only starts 0.4–3 s after launch (and on Android refuses tasks for 2.5 s). All later requests,
  including Retry, use the background lane. If the background lane refuses a task, the request runs inline.
- `SHOPBENCH home_ready` is written from `render()` in the first render where Home's loaded content (chips and
  best-seller cards) is on screen, once per process. It goes through the plugin's `Shopbench.Log` bridge function
  (`NSLog` on iOS, `Log.i("SHOPBENCH", …)` on Android).
- **Endpoint:** iOS uses `getenv('SHOP_API_URL')` from the process environment (devicectl / simctl). Android, and
  iOS without the variable, use `SHOP_API_URL` from the bundled `.env` (set at build time). Otherwise the default
  mock.shop endpoint. HTTP timeouts: 8 s connect, 20 s total.
- **Collection grid:** a `<native:list>` (SwiftUI `List` / Compose `LazyColumn`, both lazy) whose rows hold two cards.
  It is NativePHP's lazy list with an end-reached callback; `<native:lazy-grid>` has none. Pagination triggers
  when a row within 3 rows of the end is built, about one screen ahead. Column gap 12, row gap 20 as designed.
  Search results use the same list with a 6-row buffer.
- **Sort chips** in a horizontally scrolling row (they don't fit on one 390 pt line, as in the design).
- **Product price colour:** when the selected variant has a higher compare-at price, the price uses the `sale`
  colour (like the cards) with the compare-at price struck through. Search rows and recommendation cards show only
  the price, as drawn in the design. Best-seller and collection-grid cards use the sale treatment as specified.
- **Option selection:** the variant whose `selectedOptions` equal the current selection with the tapped value
  swapped in. If none matches exactly, the first variant that has the tapped value. Option pills wrap onto more
  lines if there are many.
- **Add to cart** is ignored, and the button drawn at 50 % opacity, while any cart request is in flight. The app
  switches to the Cart tab when the response has no `userErrors`. With `userErrors`, the cart is still replaced
  and the first message is shown in an alert. A network failure shows the alert "Couldn’t add to cart".
- **Cart stepper:** taps are ignored while a cart request is in flight (the stepper dims), so quantities never
  race. A failed update shows an alert.
- **Pagination failure** (a later page of a collection or search): the loading row disappears and scrolling to
  the end again retries. A first-page failure shows the error state with Retry.
- **Empty search field:** the hint text; clearing the field cancels any outstanding query. The query is trimmed.
- **Product screen while loading/failed:** round back button, then a spinner or the error state.
- Collection title is shown from the Home data immediately and replaced by the API title when it loads.
- **"See all"** link next to "Collections" in the design: not implemented. The spec doesn't list it and gives it
  no destination.
- **Colours** come from `config/native-ui.php` theme tokens matching `Tokens.dc.html`. The banner caption scrim
  is `text` at 72 % opacity. The app is pinned to light appearance (`NATIVEPHP_APPEARANCE=light`): no dark mode.
- **Icons:** the design's home, search, cart and back SVGs (plus the stepper's minus and plus) are in
  `resources/icons/`. NativePHP compiles them into vector template images (iOS asset catalog, Android
  VectorDrawable).
- **Plain white launch screen:** `public/splash.png` / `splash-dark.png` are plain white, replacing NativePHP's
  default logo splash. App icon: NativePHP's default (no custom icon was made).
- **Portrait iPhone only** (`ipad => false`, portrait orientation in `config/nativephp.php`).
- `CADisableMinimumFrameDurationOnPhone = true` and `NSAppTransportSecurity` (`NSAllowsArbitraryLoads`,
  `NSAllowsLocalNetworking`) are set through `config('nativephp.permissions')`, which NativePHP merges into
  Info.plist. Android cleartext is enabled by the plugin's `network_security_config.xml`.
- **Builds use a unique build number** (Unix time) because NativePHP only re-extracts the bundled app when the
  version or build number changes. `NATIVEPHP_APP_VERSION` is `1.0.0`; `DEBUG` would re-extract on every launch.
- `.env.example` turns logging off (`LOG_CHANNEL=null`) and uses array session/cache drivers, so nothing is
  persisted (NativePHP still creates its SQLite file, but the app stores nothing in it).

## Dependencies added

| Dependency | Why |
|---|---|
| `nativephp/mobile` 4.7.0 | The framework (required). |
| `nativephp/mobile-ui` 0.9.0 | NativePHP's own EDGE element renderers (column, text, image, list, pager…). Core has no renderers without it. |
| `nativephp/mobile-browser` 1.2.x | In-app browser (SFSafariViewController / Custom Tabs) for Check out. NativePHP core has no browser API. |
| `shopbench/native` (local, `packages/shopbench-native`) | App-local NativePHP plugin: the `Shopbench.Log` bridge function (NativePHP has no way for PHP to write to the iOS unified log) and the Android `network_security_config.xml` allowing cleartext (NativePHP's release config forbids it). |
| `laravel/framework` | NativePHP apps are Laravel apps (from the official starter). |
| `phpunit/phpunit` (dev only) | Needed by NativePHP's in-process component test harness (`Native::test()`), which I used during development. Not shipped: release bundles are built with `composer --no-dev`. |

Development-only tooling (not in the project): the AXe CLI was used to drive the iOS Simulator by accessibility
identifier during verification.

## Not met / caveats

- **Framework logging in release builds:** NativePHP's iOS shell itself calls `NSLog` (e.g. `[NativePHP] Deferred
  initialization starting`, `AsyncTaskExecutor: started`) in release builds. The app adds only the single
  `SHOPBENCH home_ready` line. Removing the framework's lines would mean modifying NativePHP, which the spec forbids.
- **NativePHP starts its queue worker and async-task pool** (extra PHP interpreters) at launch on every app. This
  isn't configurable without modifying the framework.
- **Native push/pop animations and the edge-swipe-back gesture are absent** (see "Why one screen").
- **Simulator build configuration:** NativePHP's simulator scheme always compiles Xcode's Debug configuration. The
  bundled PHP app is in release mode (see BUILD.md).
- **Signed device build not exercised end to end here:** this machine has no Apple developer account or provisioning
  profile, so `DEVELOPMENT_TEAM=… scripts/build-ios.sh device` stops at Xcode's "No Account for Team" (it passes
  `CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=… -allowProvisioningUpdates`). The unsigned device build
  (`CODE_SIGNING_ALLOWED=NO`) was verified from a clean checkout.
- **No product in the mock catalog has variants with different prices,** so the price update on variant change
  could only be checked in code and by the label and pill state changing on the simulator.
- **Accessibility element types:** identifiers come from NativePHP's `ref` attribute (iOS
  `accessibilityIdentifier`, Android `testTag` exposed as resource-id). Pressables are buttons. The
  `cart-badge` and `cart-subtotal` elements are generic elements whose accessibility label is the displayed value.
  Lists and scroll views expose their identifier on the scrolling container.
