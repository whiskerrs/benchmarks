# Everbloom (Exact): notes

## Layout of this repository

- `everbloom/` is the Exact app (`app.contract`, `product.contract`, `parts.contract`,
  `shapes.contract`: the view; `app.ts` + `graphql.ts`: the data module; `modules/apple/Shop.swift`:
  the iOS native module; `app.json`: the manifest).
  Exact names an app's crates after its directory, and the project root's name, `exact`,
  collides with Exact's own crates (`exact new` refuses it), so the app is one directory down.
- `vendor/exact2/` is the Exact checkout the app builds against (Exact has no releases or
  packages; an app uses a checkout by path). It is pinned to commit
  `fc14919528fb76ca8de3e8c8d9ef91853f923a17` and cloned by the install step in `BUILD.md`.
  It is not modified.
- `vendor/ibex/` is Expo's Ibex checkout (commit `a0183568e8229b8243629cdb26cd4a88ac4e2abd`),
  used only to build the Android Hermes bundle, which no Ibex release ships yet.
- `scripts/build-ios-device.sh` builds the iOS device release; `scripts/signing-stub/` is a
  never-shipped stub Xcode project used only to obtain Xcode's automatically managed
  provisioning profile for `DEVELOPMENT_TEAM` (Exact assembles and signs the `.app` itself,
  without an Xcode project).

## Dependencies added

- `@exact/in-app-browser` (part of the Exact checkout, `vendor/exact2/packages/in-app-browser`):
  opens `checkoutUrl` in the platform's in-app browser (SFSafariViewController on iOS, a Custom
  Tab on Android). Contract has no built-in browser view.

No third-party packages. GraphQL is sent with plain `fetch`.

## Decisions where the spec is silent

- **Architecture.** All requests go through `app.ts`. The view declares one resource per data
  set: `loadHome`, `loadCollection(handle, sort, pages)`, `searchProducts(query, pages)` and
  `loadProducts(handles)` (every product screen on either tab's stack, so stacked product screens
  each keep their data). Infinite scroll raises `pages`; `app.ts` keeps the pages it already
  fetched in memory and fetches only the next one with `after: endCursor`. Product details are
  memoized per handle for the session (successes only, so Retry refetches a failure).
- **First page variables.** `after` is omitted from `variables` on the first page (not sent as
  `null`).
- **Stale responses.** Exact drops a resource answer whose request is no longer current, so a
  search answer for an old query never replaces the current one; the view also compares the
  answer's query with the current query.
- **Cart.** The cart id is kept in `app.ts` memory. All cart operations go through one queued
  mutation, so they apply in order; the displayed cart is the latest reply's `cart`. A transport
  failure on a cart operation shows the alert "Check your connection and try again." (the spec
  defines alerts only for `userErrors`). The alert's title is "Couldn’t update cart"; its
  message is the first `userErrors` message.
- **Add to cart.** The tab switches to Cart when the add's reply arrives without `userErrors`.
  The button is disabled while any cart request is in flight.
- **Product screen.** The round back button is fixed over the top-left corner of the screen
  (it stays reachable when the page scrolls) instead of scrolling away with the carousel.
  The Add to cart bar sits below the scroll area rather than over it. Option pills wrap onto
  more lines when they do not fit. Picking a pill selects the variant matching all current
  options with the new value; if no variant has that combination, the first variant with the
  picked value.
- **Collection screen.** The navigation bar, description and sort chips stay fixed; the product
  grid below them is the scrolling container (`product-grid`), a virtualized list of rows of
  two cards. The sort chips scroll horizontally when they do not fit. The title shows the
  collection's title from Home while the collection loads.
- **Home.** The "See all" link in the design is not in the spec and is omitted. The header
  scrolls with the content ("the whole screen scrolls").
- **Errors.** A failed first page shows the full error state; a failed later page (collection,
  search) shows an inline "Couldn’t load products" with Retry at the end of the list, keeping
  the loaded rows.
- **Search.** Shows a spinner while the first page of a query loads. "1 result" is singular.
- **Empty cart.** "Start shopping" switches to the Home tab.
- **Status bar / dark mode.** Colors are the design's fixed light palette on every system theme.

- **Benchmark hooks.** `SHOPBENCH home_ready` is written with `os_log` by the Swift module
  (`everbloom/modules/apple/Shop.swift`) when Home first shows its chips and best sellers: a root
  `task` runs once `home.loaded` is true and sends a mutation whose source calls the module, which
  logs once per process. Test ids are Contract `testId`s, which Exact's UIKit host sets as each
  view's `accessibilityIdentifier`. The tab bar, headers and back buttons are drawn by the app
  (`appearance="none"` tab bar, `navigationBar="none"` routes) so they follow the design and carry
  the required ids; the edge swipe still goes back.
- **Endpoint.** iOS reads `SHOP_API_URL` from the launch environment through the Swift module; if
  it is empty, the build-time `SHOP_API_URL` (`app.json` `env`) is used; else mock.shop. Android
  uses the build-time value. The grants are `net.fetch https:` and `net.fetch http:` (any host),
  and iOS sets `NSAllowsArbitraryLoads` (`host.ios.appTransportSecurity`).
  The endpoint is resolved once at launch by a mutation (`shopEndpoint`), and every resource takes
  it as an argument. No resource may touch the native module: Exact marks a resource whose source
  reads device state (any native-module call counts) as a "store reader" and persists its last
  answer, which the next launch shows before the network answers. That would break the
  no-persistence rule, the skeleton-on-first-frame rule and the error state for an unreachable
  endpoint. Before this change a relaunch showed the previous session's Home; after it, all three
  hold.
- **Tab bar layout.** The tab bar is laid over the bottom of the screens (as the design draws it)
  and every screen that shows it pads its bottom by `49px + env(safe-area-inset-bottom)`. Exact's
  UIKit host lays each route out full-screen behind the bar, so an in-flow bar would leave the Cart
  summary under it on iOS.
- **iOS manifest.** iPhone only, portrait, white launch screen (`background_color`), no icon.
  `CADisableMinimumFrameDurationOnPhone` is written by Exact for every iOS app.
- **Unsigned device build and the placeholder icon.** Without `DEVELOPMENT_TEAM`, the only device
  packaging Exact offers with no phone and no team is its distribution archive
  (`--archive --unsigned`), which refuses a bundle without an app icon. For that build only,
  `scripts/build-ios-device.sh` names a plain white 1024 px placeholder
  (`scripts/unsigned-placeholder-icon.png`) and restores `app.json` afterwards. The signed
  (benchmarked) build has no icon.

## Verification (iOS 27.2 Simulator, Xcode 27.2)

- **Release build** (`scripts/build-ios-simulator.sh`, Exact production mode), driven by an XCUITest
  harness that addresses the app by bundle id (kept outside the project): every identifier in
  the spec's table was found by XCUITest. Walkthrough: Home loads; a collection opens, each of the
  four sorts reloads, the grid scrolls to its end; a product opens, the carousel swipes, an
  option pill switches the variant, a recommendation pushes another product and Back returns;
  Add to cart switches to Cart with the badge ("1"); the stepper changes the subtotal
  ($75.00 → $150.00); Check out opens the checkout URL in Safari's in-app view
  (SFSafariViewController), which closes again; reducing to 0 removes the line and the badge and
  shows the empty state; search returns results and scrolls.
- **Endpoint override and error state.** Launched with `SHOP_API_URL` pointing at a stopped local
  proxy (`scripts/dev-proxy.ts`), Home shows the error state; with the proxy started, Retry
  loads Home (the proxy logged the `Home` request), also right after a successful session.
- **Log marker.** `SHOPBENCH home_ready` appears exactly once per launch in
  `xcrun simctl spawn … log stream` (two launches, one line each). Apart from it, only system
  frameworks log from the process.
- **First frame.** Exact's driver captured the skeleton as the app's first frame.
- **Exact's driver** (`bun exact.mjs agent ios`, development build): collection paging to the end
  (4 pages), all sorts, search paging to the end (81 of 81 for "jacket", rows virtualized),
  options, carousel dots, recommendations, cart stepper and empty state; screenshots checked
  against the design.
- **Device build** (`scripts/build-ios-device.sh` without a team): builds an arm64 iOS release
  bundle, ad-hoc signed.
- **Android:** the release APK builds and launches on an Android emulator, and Home loads.
- **Web host:** `everbloom/app.test.contract` (3 tests) passes.

## What could not be met, and why

- **The signed device build was not run.** No iPhone has been paired with this Mac, and running
  `DEVELOPMENT_TEAM=… scripts/build-ios-device.sh` would register the bundle id and a
  provisioning profile in a real Apple Developer account, which this run did not do unasked. The
  unsigned path compiles the same release code for arm64; the signed path differs in signing and
  packaging (stub-project profile, then Exact's `ios --device --release --no-install` instead of
  its distribution archive).
- **The `userErrors` alert** was not seen: no path through the UI makes mock.shop return
  `userErrors`.
- No mock.shop product has variants with different prices, so the price change on a variant
  switch could only be checked as "the price shown is the selected variant's".
- **XCUITest and Safari's close button.** On iOS 27, XCUITest's element tap on
  SFSafariViewController's ✕ ("Close") does not close it, while a coordinate tap does.
