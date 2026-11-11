# Notes

## Project layout

- `app/app.ts`, `app/app-root.xml|ts`: root layout = one `Frame` per tab plus a custom tab bar.
- `app/pages/*`: Home, Collection, Product, Search, Cart (XML + TypeScript code-behind, core `Observable` view models).
- `app/lib/api.ts`: endpoint resolution and the GraphQL documents (copied verbatim from `spec/storefront.graphql`), sent with core `Http.request`.
- `app/lib/cart.ts`: in-memory cart store; `app/lib/paged-list.ts`: infinite scroll for `ListView`; `app/lib/grid.ts`: 2-column grid rows.
- `app/components/icon.ts`: the design's stroke icons drawn natively (CAShapeLayer / Android ShapeDrawable).
- `App_Resources/iOS/src/SBNative.{h,m}`: small Objective-C helper for `os_log` (benchmark marker) and `SFSafariViewController`.

## Dependencies added

None beyond the NativeScript project itself. `package.json` contains only
`@nativescript/core` (runtime) and the NativeScript toolchain packages
(`nativescript` CLI, `@nativescript/ios`, `@nativescript/android`,
`@nativescript/webpack`, `@nativescript/types`, `typescript`). The template's
`@nativescript/theme` was removed.

Build-time only: the Ruby `xcodeproj` gem, which the NativeScript CLI itself
requires to merge xcconfig files; it is installed into `./.gems` by
`scripts/setup.sh` and exposed to the CLI through the `scripts/bin/ruby` shim.

The in-app browser uses the system `SFSafariViewController` (SafariServices,
linked via `App_Resources/iOS/build.xcconfig`) instead of a plugin.

## Decisions where the spec is silent

- **Tab bar**: a custom bar (NativeScript `GridLayout`) over three `Frame`s instead of the core `TabView`, because it needs a badge, the design's vector icons, accessibility identifiers per tab, and must hide on the Product screen. The Search and Cart frames are created on first use so that launch only builds Home. Tab switching keeps each frame's stack.
- **Navigation bars**: native action bars are hidden; each screen draws the design's header (44pt). The back button calls `Frame.goBack()`. No transitions beyond NativeScript's default push animation.
- **"See all"** link next to "Collections" in the design is not described in the spec, so it is omitted.
- **Collection header**: nav bar, description and sort chips stay fixed above the scrolling grid (the grid `ListView` is the `product-grid` container).
- **Grid rows**: the grid is a `ListView` whose rows hold two cards, with a fixed row height (image 3:4 + two title lines + price + 20pt gap). Titles are clamped to 2 lines, so all rows are the same height. The loading row at the end has the same height with the spinner at its top.
- **Infinite scroll trigger**: on iOS the table's `contentOffset` is observed (KVO) and the next page is requested when less than one viewport height of content remains below the visible area. On Android it is triggered when a row within one screen of the end is built.
- **Sort change**: clears the grid and shows a spinner until the first page of the new order arrives.
- **Search**: the debounce timer is 300 ms after the last keystroke; the query is trimmed; responses for stale queries (and stale pages) are dropped. While the first page loads a spinner is shown. Result rows are fixed at 101pt (64×85 thumbnail + 8pt padding), titles up to 3 lines.
- **Product carousel**: horizontal `ScrollView` with native paging (`pagingEnabled`) on iOS; on Android it snaps to the nearest page after scrolling stops. Page dots are hidden when there is only one image. The round back button stays fixed over the top-left corner while the page scrolls.
- **Option pills** wrap onto multiple lines when they do not fit. Selecting a value picks the variant matching all currently selected options with that one changed; if no variant matches exactly, the first variant having that value is selected.
- **Prices**: the product price uses the `sale` color when the selected variant's compare-at price is higher, with the compare-at price struck through next to it. Recommendation cards follow the same rule as product cards. (No product in the catalog has variants with different prices, so switching variants changes the selection and labels but the price stays the same in practice.)
- **Add to cart**: the button is disabled while the request is in flight; on success the app switches to the Cart tab. On a network failure an alert ("Couldn't update cart" / "Check your connection and try again.") is shown and the tab is not switched.
- **Cart mutations** are serialized. Stepper taps are applied as +1/−1 against the latest cart returned by the server, so rapid taps are not lost. Network failures show the same alert as above.
- **Empty cart**: the "Start shopping" button switches to the Home tab.
- **Error state**: shown on Home, Collection, Search and Product when the request fails (HTTP error, GraphQL response without `data`, or a 30 s timeout). Retry repeats the request. The cart has no load request, so it has no error state.
- **Loading states**: Home shows the design's skeleton on the first frame; Collection, Search and Product show a centered spinner.
- **Status bar / safe areas**: scrolling content stays below the status bar; only the product image carousel extends under it.
- **Images**: core `Image` with `loadMode="async"` and `stretch="aspectFill"`; the placeholder is the `surface` color behind the image.
- **App name / IDs**: NativeScript names the Xcode project and built `.app` after the project directory; the build scripts copy the result to a fixed `build/ios-*/Everbloom.app`. The display name is `Everbloom` and the bundle/application ID is `dev.whiskerrs.shopbench.nativescript`.
- **App icon**: the NativeScript template's default icon is left as is (no custom icon). The launch screen is plain white (template images removed) on both platforms.
- **Endpoint override**: iOS reads `SHOP_API_URL` from the process environment at launch. A build-time `SHOP_API_URL` (webpack `DefinePlugin`) is supported on both platforms and is what Android uses; the iOS launch variable wins if both are set.
- **Plain HTTP**: iOS `NSAllowsArbitraryLoads` + `NSAllowsLocalNetworking`; Android `usesCleartextTraffic` and a network security config permitting cleartext.
- **Portrait only, iPhone only** (`UIDeviceFamily` 1); light appearance forced (`UIUserInterfaceStyle` Light) since dark mode is out of scope.
- **Logging**: the only log written by app code is `SHOPBENCH home_ready` via `os_log` (default level), once per process, scheduled right after the loaded Home content is bound. Release webpack builds also strip any `console.*` calls. The NativeScript iOS runtime prints one "Runtime initialization took …" line to stdout at startup; that is NativeScript's own output and does not go to the unified log.

## NativeScript ListView workarounds (iOS)

Getting the lazily rendered lists to behave under scrolling and XCUITest needed some care; these are worth knowing when reading `app/lib/paged-list.ts` and `app/lib/grid.ts`:

1. **Fixed `rowHeight`.** Without it, NativeScript measures rows with a separate measurement pass that re-binds views and left cells with stale data/identifiers.
2. **Rows are filled imperatively in `itemLoading`** (no `{{ }}` bindings inside the row templates). Bindings inside recycled cells were unreliable for some properties (image `src`, `testID`).
3. **Cell views are kept attached to their cells.** When a `UITableViewCell` leaves the window NativeScript tears down its item view and rebuilds it when the cell is reused; that rebuild threw inside `cellForRowAtIndexPath` and UIKit aborted the app. The app overrides `_removeContainer` on its own `ListView` instances (no change to NativeScript itself) so each item view simply stays with its reusable cell.
4. **Paging is driven by scroll position, not by `itemLoading`.** The accessibility snapshot XCUITest takes makes UITableView build cells for off-screen rows, which would otherwise fetch every page at once.
5. **List images are styled natively** (layer background color and corner radius set in the image's `loaded` event) for the same rebuild reason as in point 3.
6. **Accessibility identifiers inside cells**: cards and search rows are marked `accessible="true"` so XCUITest exposes their identifiers (it hides nested non-accessible views inside table cells). Their accessibility label is the product title.

## Spec items not met / caveats

- All required items were met on the iOS Simulator. Since no device was available, the device build was verified to compile and sign-less build succeeds (`CODE_SIGNING_ALLOWED=NO`); it has not been run on hardware.
- Product price switching could not be visibly demonstrated because no catalog product has variants with different prices (see above).
- Android (only required to launch and load Home, which it does): the app was not tuned for Android 15+ edge-to-edge, so the gesture-navigation handle overlaps the bottom of the tab bar on the API 36 emulator.
- Android: the Check out button opens the system browser (`Utils.openUrl`), because an in-app Custom Tab would need the `androidx.browser` dependency.
