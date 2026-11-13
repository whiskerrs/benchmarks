# Notes

## Dependencies

None. The app uses only Apple frameworks: SwiftUI, Foundation (`URLSession`, `JSONDecoder`), SafariServices
(`SFSafariViewController` for the in-app checkout browser) and `os` (`os_log` for the benchmark marker).

Build-time only (optional): XcodeGen generated `Everbloom.xcodeproj` from `project.yml`. The generated project is checked
in, so building does not need XcodeGen.

## Project layout

- `Everbloom/`: app sources (`App.swift` = root, tabs, routing; one file per screen; `API.swift` = GraphQL over
  `URLSession`, with the operation documents copied verbatim from `spec/storefront.graphql`).
- `EverbloomUITests/`: XCUITest target used only to verify flows and accessibility identifiers on the simulator. It
  is not part of the benchmarked app.

## Decisions where the spec is silent

- **Minimum iOS:** 18.0 (needed for `onScrollGeometryChange`, used for the infinite-scroll trigger). Language mode is
  Swift 5.
- **Tab bar:** a custom SwiftUI bar instead of `TabView`. That is the simplest way to match the design (custom vector
  icons, 49 pt bar, the badge position and color), to attach the `tab-*` and `cart-badge` identifiers, and to hide the
  bar on Product. The three tabs sit in a `ZStack` and the inactive ones are hidden, so each tab keeps its own
  `NavigationStack` path. Tapping the active tab does nothing.
- **Navigation bar:** the system navigation bar is hidden and every screen draws the header from the design with a
  custom back button (`back`). Because of that the edge-swipe-back gesture is unavailable; the back button pops.
- **Product back button** floats at the top-left of the screen (below the status bar). It stays put while the content
  scrolls.
- **Home "See all" link** in the design is not in the spec's feature list and has no defined target, so it is left out.
- **Price display:** the sale styling (sale-colored price followed by the struck-through compare-at price) is used
  wherever a product card price appears: Home, Collection, Search rows and recommendations.
- **Featured label:** rendered as "Featured collection" with uppercase text case, as in the design.
- **Collection screen:** the header, description and sort chips stay fixed; only the product grid scrolls
  (`product-grid`). The title comes from the tapped collection and is replaced by the API title once loaded. Changing
  the sort clears the grid and shows a spinner while the first page loads.
- **Infinite scroll:** the next page is requested when the distance from the visible bottom to the content end is less
  than one container height. If loading a next page fails, the spinner disappears and the next scroll triggers a new
  attempt (the full-screen error state is used only for first-page failures).
- **Search:** the query is trimmed. Each keystroke clears the current results and shows a spinner until the debounced
  request (300 ms) returns. Responses are discarded when their query, or the request generation, is no longer current.
  The count label reads "`<totalCount>` results" literally, even for 1.
- **Loading UI:** Home uses the skeleton from `States.dc.html`. Collection, Product and Search show a centered
  spinner on first load.
- **Variant selection:** tapping a pill selects the variant whose `selectedOptions` match the current selection with
  that option changed. If no variant matches exactly, the first variant that has that option value is selected.
  Page dots are shown only when the product has more than one image.
- **Add to cart:** while the request runs the button is disabled and dimmed. The app switches to the Cart tab when the
  mutation returns a cart with no `userErrors`. If there are `userErrors`, the first message is shown in an alert and
  the app stays on Product. If the response has `cart: null`, the displayed cart is kept.
- **Stepper:** while any cart mutation is in flight, the stepper buttons are disabled.
- **Network failure on a cart mutation** (not covered by the spec): an alert says "Couldn't update the cart. Check your
  connection and try again."
- **Empty cart:** shows the design's "Your cart is empty" state. Its "Start shopping" button switches to the Home tab.
- **Checkout** opens `checkoutUrl` in `SFSafariViewController` presented as a sheet. Done closes it.
- **Images:** `AsyncImage` with an enlarged `URLCache` (64 MB memory / 256 MB disk). Images are not persisted beyond
  the system URL cache.
- **Info.plist:** light appearance forced (`UIUserInterfaceStyle = Light`), portrait only, iPhone only, empty
  `UILaunchScreen` (plain white), `NSAllowsArbitraryLoads` + `NSAllowsLocalNetworking`. It also sets
  `NSLocalNetworkUsageDescription`, because iOS asks the user for Local Network permission the first time the app
  contacts a LAN address such as the replay server. That permission prompt may need to be accepted once on the test
  device.
- **Log marker:** `os_log("SHOPBENCH home_ready")` is written once per process, when the loaded Home content first
  appears. The app writes no other logs.
- **Endpoint override:** `SHOP_API_URL` is read from the process environment at launch (trimmed; empty means default).

## Verification performed (iOS Simulator, Release build)

Checked with the UI test target on an iPhone 17 Pro simulator (iOS 27.2):

- Home loads.
- The "Urban Transit Essentials" collection scrolls to its 84th (last) product, and each of the four sorts reloads it.
- Search for "shirt" scrolls through all 67 results, and a result opens its product.
- A product option switches the selected variant. No product in the top 100 has variants with different prices, so
  the price change could not be seen on this catalog.
- A recommendation opens another product.
- Add to cart switches to Cart with the badge at 1. The stepper raises the quantity, badge and subtotal; reducing to 0
  shows the empty state and hides the badge.
- Check out opens the mock checkout page in the in-app browser.
- With the endpoint unreachable, Home shows the error state, and Retry loads Home once the endpoint is up.
- `SHOPBENCH home_ready` appears once per launch.
- Every identifier in the spec's table was found by XCUITest.

## Not met / limitations

- No physical device was available. The device build was verified only to compile, unsigned
  (`CODE_SIGNING_ALLOWED=NO`).
