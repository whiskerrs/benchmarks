# Notes

## Dependencies

No third-party dependencies were added. Everything uses Apple frameworks:

- **UIKit**: all UI.
- **SafariServices** (`SFSafariViewController`): the in-app browser for Check out. It ships with iOS, so no third-party browser is needed.
- **os** (`os_log`): writes the single `SHOPBENCH home_ready` line.

XcodeGen generated `Everbloom.xcodeproj` from `project.yml`. It is a development tool, not an app dependency, and the generated project is checked in.

## Project structure

- `Everbloom/`: app sources. The app is built in code with no storyboards.
  - `API.swift`: GraphQL over plain `URLSession` POST requests, with the documents copied verbatim from `spec/storefront.graphql`.
  - `CartStore.swift`: the in-memory cart.
  - `ImageLoader.swift`: image loading with an in-memory cache.
  - `Components.swift`, `Theme.swift`: shared views, design tokens, and the vector icons.
  - One view controller per screen.
- `EverbloomUITests/`: XCUITest flows used for verification. Not part of the app.

## Decisions where the spec was silent

- **GraphQL documents.** Each request's `query` contains that operation plus the fragments it uses (`ProductCard` or `CartFields`), copied verbatim from `spec/storefront.graphql`. Optional variables with no value (`after` on the first page) are sent explicitly as `null`.
- **Request timeout.** API requests time out after 20 s, so an unreachable endpoint reaches the error state in reasonable time.
- **Tab bar.** The app uses the standard `UITabBarController`. On iOS 26 and later this draws the system's floating "Liquid Glass" tab bar, not the flat bar in the mockup. Tab colors, icons, and label fonts follow the design tokens.
- **Cart badge.** UIKit's native `badgeValue` view is private and cannot carry an accessibility identifier. The badge is therefore a `UILabel` overlaid on the Cart tab item, styled as the design specifies (18 pt, `sale` color, 11 pt bold) and identified as `cart-badge`. It is positioned from the frame of the tab's button.
- **Navigation bars.** Home, Search, Cart and Product draw their own headers, so the navigation bar is hidden there. Collection uses the system navigation bar with a custom back item (identifier `back`) that uses the design's back icon. Swipe-back still works.
- **Collection header.** The description and sort chips stay fixed above the scrolling grid (`product-grid`). The grid is a `UICollectionView` with a compositional layout (cells are reused, so rendering is lazy). It is fed by a `UICollectionViewDiffableDataSource`, so pages that arrive back to back (for example from a fast replay server) can never leave the collection view and the model out of sync. Cards have a fixed height that reserves two title lines.
- **Infinite scroll.** The next page loads when less than one screen height of content remains below the viewport. This is also checked after each page arrives and when the screen appears, in case the content is shorter than the screen. The check lays out the list first so it never measures a stale `contentSize`. If a later page fails, the list stays as it is, and scrolling tries again. Only a failure on the first page shows the error state.
- **Search.** The query is trimmed. A whitespace-only query counts as empty. While a new query loads, earlier results are cleared and a spinner shows. Responses are discarded unless they match the current query and request generation. Return dismisses the keyboard.
- **Price display.** Wherever a `ProductCard` price is shown with the 15 pt price style (Home, Collection, Search rows), the sale color and struck-through compare-at price apply when compare-at is higher. Recommendation cards show only the price at 14 pt bold, as drawn in the design.
- **Variant selection.** Tapping a pill looks for the variant matching the current selection with that one option changed. If no such variant exists, it picks the first variant that has the tapped value.
- **Image carousel.** A paging `UICollectionView` with a `UIPageControl` (the page dots). The round back button is pinned to the top-left of the screen, below the status bar. It stays visible while loading, on error, and while scrolling.
- **Add to cart.** The button is disabled while a request is in flight. On success the app switches to the Cart tab. If the response has `userErrors`, the first message is shown in an alert and the tab does not switch. Network failures also show an alert.
- **Quantity stepper.** Only one cart mutation runs at a time. Taps made while one is in flight are ignored. Decrementing from 1 sends quantity 0, which removes the line.
- **Empty cart.** Follows the design: icon, "Your cart is empty", "Items you add will appear here.", and a "Start shopping" button that switches to the Home tab.
- **Home "See all" link.** It is drawn in the mockup's Collections header, but the spec doesn't list it, so it is omitted. Every collection is already reachable from the chips and the carousel.
- **Loading states.** Home shows the design's skeleton from the first frame. Collection, Search and Product show a spinner. The Collection and Search lists show a small spinner at the end while the next page loads.
- **Error text.** The error title uses the spec's spelling with a straight apostrophe: "Couldn't load products".
- **Appearance.** Light mode is forced (`UIUserInterfaceStyle = Light`). The app is portrait only, iPhone only. The launch screen is an empty `UILaunchScreen`, which renders plain white.
- **ATS.** `NSAllowsArbitraryLoads` and `NSAllowsLocalNetworking` are set, and an `NSLocalNetworkUsageDescription` is provided because iOS asks for permission before an app reaches LAN addresses.
- **Readiness marker.** `SHOPBENCH home_ready` is logged once per process with `os_log`, right after the loaded Home content (chips and best-seller cards) has been laid out. Nothing else is logged.

## Not met / limitations

- The tab bar does not match the flat 49 pt bar in the mockup. On current iOS, UIKit draws the system Liquid Glass tab bar, and that is kept as the platform default.
- Not verified on a physical device. The device build was checked with `CODE_SIGNING_ALLOWED=NO`, and the signed build depends on the benchmark's `DEVELOPMENT_TEAM`.
