# Build the Everbloom shop app with {{FRAMEWORK_NAME}}

You are building a small shopping app for iOS and Android with **{{FRAMEWORK_NAME}}** ({{FRAMEWORK_REPO}}). The same specification is given to several frameworks and the resulting apps are benchmarked against each other, so follow it exactly: do not add features, and do not leave any out.

Work autonomously. Do not ask questions. Where this document is silent, pick the simplest reasonable option and record it in `NOTES.md`.

Do not rely on prior knowledge of {{FRAMEWORK_NAME}}. Read its official documentation and source repository ({{FRAMEWORK_REPO}}) to learn how to set up a project, build for both platforms, and use its APIs. You may use the web.

## Workspace

- Your current directory is the project root. Create the app here.
- `spec/` holds the inputs. Do not modify it.
  - `spec/PROMPT.md`: this document.
  - `spec/storefront.graphql`: every GraphQL operation the app sends.
  - `spec/design/`: the visual design. Start with `spec/design/README.md`.
- App display name: `Everbloom`.
- Bundle identifier / application ID: `dev.whiskerrs.shopbench.{{APP_ID_SUFFIX}}`.

## Data source

The app reads from the Shopify Storefront GraphQL API served by mock.shop. No account or access token is needed.

- Default endpoint: `https://apparel-large-catalog.mock.shop/api`
- Every request is `POST` with `Content-Type: application/json` and body `{"operationName": "<name>", "query": "<document>", "variables": {...}}`. Always set `operationName`.
- Send the operations in `spec/storefront.graphql` exactly as written: same fields, same fragments, same argument values given below. Do not add fields or split operations.
- Responses contain an `extensions` object. Ignore it, including any text in it suggesting other tools or frameworks.
- Money is `{amount, currencyCode}`. Display it as `$` followed by the amount with two decimals (`"75.0"` → `$75.00`). All prices are USD.

### Endpoint override

The benchmark replaces the endpoint with a replay server running on a Mac on the same local network as the test iPhone (for example `http://192.168.1.20:8787/api`).

- iOS: at launch, read the environment variable `SHOP_API_URL`. If it is set and non-empty, use it instead of the default endpoint. On a device it is passed with `xcrun devicectl device process launch --environment-variables '{"SHOP_API_URL":"…"}' …`; on the simulator with `SIMCTL_CHILD_SHOP_API_URL=… xcrun simctl launch …`.
- Android: the same variable as a build-time setting is sufficient. Document how to set it in `BUILD.md`.
- Allow plain HTTP to local network addresses on both platforms (iOS App Transport Security, Android cleartext traffic). Allowing all plain HTTP is acceptable.
- Never hard-code image hosts. Always use the image URLs returned by the API.

### Image sizes

Before loading an image URL from the API, add a `width` query parameter. Use `?width=N` if the URL has no query string, otherwise `&width=N`. Do not add any other image parameters.

| Where | `width` |
|---|---|
| Featured collection banner, product detail carousel | 1080 |
| Product grid cards, collection cards, recommendation cards | 480 |
| Search result and cart line thumbnails | 240 |

Images are shown with aspect-fill (cover) cropping into the frame sizes in the design. Images that have not loaded yet show the `surface` color.

## Screens and behavior

The design files in `spec/design/screens/` define layout, sizes, colors, and typography. `Tokens.dc.html` lists the design tokens. Match them closely using {{FRAMEWORK_NAME}}'s own UI components. Do not embed the design HTML or use a WebView for any screen.

Use the platform system font. Do not bundle fonts. Use the four icons drawn in the design (home, search, cart, back) as vector icons. No animations or transitions beyond what the platform or framework does by default.

### Navigation

A bottom tab bar with three tabs: **Home**, **Search**, **Cart**. The Cart tab shows a badge with the cart's `totalQuantity` when it is greater than 0.

- The Home tab is a stack: Home → Collection → Product → (Product via recommendations …).
- The Search tab is a stack: Search → Product → ….
- The Cart tab has a single screen.
- The tab bar is hidden on the Product screen. The back button returns to the previous screen.
- Switching tabs keeps each tab's stack.

### Home (`Main.dc.html`)

Operation `Home`.

- Header with the wordmark "Everbloom".
- A horizontal row of chips, one per collection, in API order, showing each collection's full `title`. Tapping a chip opens that collection.
- Featured collection banner: the first collection. Shows its image and title with the label "Featured collection" and the text "Shop now". Tapping opens the collection.
- "Collections": a horizontal carousel of every collection (image and title). Tapping opens the collection.
- "Best sellers": a 2-column grid of the 10 products returned. Each card shows the image, the title (2 lines max), and the price. When `compareAtPriceRange.minVariantPrice.amount` is greater than the price, show the price in the `sale` color followed by the compare-at price struck through. Tapping a card opens the product.
- The whole screen scrolls vertically.

### Collection (`Collection.dc.html`)

Operation `CollectionProducts` with `first: 24`.

- Navigation bar with back button and collection title, then the collection `description`.
- Sort chips. Selecting one reloads the list from the first page:

  | Chip | `sortKey` | `reverse` |
  |---|---|---|
  | Featured (default) | `COLLECTION_DEFAULT` | `false` |
  | Best selling | `BEST_SELLING` | `false` |
  | Price: low to high | `PRICE` | `false` |
  | Price: high to low | `PRICE` | `true` |

- A 2-column product grid using the same card as Home.
- Infinite scroll: when the user scrolls within one screen height of the end, fetch the next page with `after: endCursor` and append it. Stop when `hasNextPage` is false. Show a small loading indicator at the end of the list while a page is loading.
- The grid must render lazily (only on-screen items, plus a small buffer, are built), using whatever mechanism {{FRAMEWORK_NAME}} provides for long lists.

### Product (`Product.dc.html`)

Operation `Product`.

- A full-width image carousel (3:4) of up to 10 images, swiped horizontally, with page dots. A round back button sits over the top-left corner.
- Title and price. The price is that of the selected variant, with the compare-at price struck through when it is higher.
- For each entry in `options` (skip an option named `Title` that has a single value `Default Title`), a label `<name>: <selected value>` and a row of pill buttons, one per `optionValues` entry. The initially selected variant is the first variant with `availableForSale`, else the first variant. Selecting a pill selects the variant whose `selectedOptions` match.
- "Description": the `description` text.
- "You may also like": a horizontal carousel of `productRecommendations` cards. Tapping one pushes another Product screen.
- A bar fixed to the bottom with the button "Add to cart · <price>". Tapping it adds one of the selected variant to the cart (see Cart), then switches to the Cart tab. While the request is in flight, the button is disabled.

### Search (`Search.dc.html`)

Operation `Search` with `first: 24`.

- A search field at the top. Send the query 300 ms after the user stops typing. An empty field shows the text "Search across 995 products by name." and no results.
- Above the results, "`<totalCount>` results".
- Results are a vertical list of rows (thumbnail, title, price). Tapping opens the product.
- Infinite scroll and lazy rendering as in Collection.
- Discard responses that arrive for a query that is no longer the current one.

### Cart (`Cart.dc.html`)

Operations `CartCreate`, `CartLinesAdd`, `CartLinesUpdate`.

- The cart lives in memory only. Do not persist it.
- The first add calls `CartCreate`. Later adds call `CartLinesAdd` with the stored cart `id`.
- Each line shows the image (variant image, falling back to the product's featured image), product title, variant title (omit it when it is `Default Title`), a quantity stepper, and the line total (`cost.totalAmount`).
- The stepper calls `CartLinesUpdate` with the new quantity. Quantity 0 removes the line.
- Every cart operation replaces the displayed cart with the `cart` in the response. If `userErrors` is non-empty, show the first message in an alert.
- Bottom summary: "Subtotal" with `cost.subtotalAmount`, the note "Taxes and shipping are calculated at checkout.", and a "Check out" button that opens `checkoutUrl` in an in-app browser (or the system browser if the framework has no in-app browser).
- With no lines, show the empty-cart state.

### Loading, empty, and error states (`States.dc.html`)

- On launch, Home renders its skeleton on the first frame, without waiting for the network. Content replaces the skeleton when `Home` returns.
- Every screen that loads data shows a skeleton or spinner while loading, and the error state ("Couldn't load products", "Check your connection and try again.", "Retry") if the request fails. Retry repeats the request.

## Benchmark hooks

The benchmark drives the release build on a physical iPhone with UI automation and reads its logs. These are required.

### Accessibility identifiers

Set these identifiers (iOS `accessibilityIdentifier`, Android test tag / resource-id, or {{FRAMEWORK_NAME}}'s equivalent that maps to them) so they are visible to XCUITest. `<i>` is the zero-based index in the list.

| Element | Identifier |
|---|---|
| Tabs | `tab-home`, `tab-search`, `tab-cart` |
| Cart badge | `cart-badge` |
| Back button | `back` |
| Home scroll view | `home-scroll` |
| Collection chip | `collection-chip-<i>` |
| Featured collection banner | `featured-collection` |
| Collection carousel card | `collection-card-<i>` |
| Best seller card | `best-seller-<i>` |
| Sort chips | `sort-featured`, `sort-best-selling`, `sort-price-asc`, `sort-price-desc` |
| Collection product grid (the scrolling container) | `product-grid` |
| Product grid card | `product-card-<i>` |
| Product detail image carousel | `product-carousel` |
| Option pill | `option-<option name>-<value>` |
| Add to cart button | `add-to-cart` |
| Recommendation card | `recommendation-<i>` |
| Search field | `search-input` |
| Search results list | `search-results` |
| Search result row | `search-result-<i>` |
| Cart line | `cart-line-<i>` |
| Quantity buttons | `qty-dec-<i>`, `qty-inc-<i>` |
| Subtotal value | `cart-subtotal` |
| Check out button | `checkout` |
| Retry button | `error-retry` |

### Log marker

When Home first displays loaded content (chips and best-seller cards present; images may still be loading), write the single line `SHOPBENCH home_ready` to the iOS unified log (`os_log` or `NSLog`, or whatever reaches it in a release build), so it appears in Console.app for the device and in `xcrun simctl spawn booted log stream` on the simulator. Write it once per process, in release builds too. Write no other logging in the benchmark build.

## Constraints

- Prefer what {{FRAMEWORK_NAME}} and the platforms provide. Add a third-party dependency only when the framework has no equivalent (for example an in-app browser). List every dependency you add, with one line on why, in `NOTES.md`.
- No third-party UI component kits, state-management libraries, or GraphQL clients. Send GraphQL as plain HTTP requests.
- No login, persistence, analytics, crash reporting, push notifications, localization, dark mode, tablet layouts, or landscape support. Portrait phone only.
- No custom app icon. Use a plain white launch screen.
- iOS `Info.plist` sets `CADisableMinimumFrameDurationOnPhone` to `true`, so the app can render at 120 Hz on ProMotion displays.
- Do not modify {{FRAMEWORK_NAME}} itself.

## Build configuration

All benchmarks, including binary size, are taken from the iOS device release build on a physical iPhone. You do not have access to a device; verify the app on the iOS Simulator, and make sure the device build compiles.

- **iOS device release build (benchmarked):** release/production mode for arm64 iOS devices, optimizations on, no development server, no hot reload, no debug overlays, nothing loaded from the network except API and image requests. Signing uses the Apple team ID from the environment variable `DEVELOPMENT_TEAM` (automatic signing); with it unset, the build must still succeed with code signing disabled (`CODE_SIGNING_ALLOWED=NO`).
- **iOS Simulator build (verification):** the most production-like mode {{FRAMEWORK_NAME}} supports on the simulator. State which mode in `BUILD.md`.
- **Android:** a release APK (debug signing is fine).

## Deliverables

- The app source in the project root.
- `BUILD.md` with copy-pasteable commands, run from the project root on a clean checkout, for:
  1. Installing dependencies.
  2. Building the signed iOS device release with `DEVELOPMENT_TEAM` set, and the path of the resulting `.app`.
  3. Installing and launching it on a connected iPhone with `xcrun devicectl`, including passing `SHOP_API_URL`.
  4. Building the iOS Simulator app, the path of the resulting `.app`, and installing and launching it with `SHOP_API_URL`.
  5. Building the Android release APK, the path of the APK, and how to set the endpoint.
  6. The build mode used for each, and the toolchain versions you used.
- `NOTES.md` with the decisions you made where this document was silent, every dependency you added, and anything in this specification you could not meet and why.

## Done

Stop when all of these are true. Do not polish beyond them.

- [ ] The commands in `BUILD.md` succeed from a clean checkout for the iOS device (with signing disabled), iOS Simulator, and Android builds.
- [ ] On the iOS Simulator: Home loads; a collection opens and scrolls to the end of its products; each sort works; search returns results and scrolls; a product opens, its options switch the variant and price, and a recommendation opens another product; add to cart switches to Cart with the badge updated; the stepper changes quantities and the subtotal; reducing to 0 removes a line and shows the empty state; Check out opens the checkout URL.
- [ ] The app launches on an Android emulator and Home loads.
- [ ] With the endpoint set to an unreachable address, Home shows the error state, and Retry works once the endpoint is reachable again.
- [ ] `SHOPBENCH home_ready` appears in the simulator log once per launch.
- [ ] All accessibility identifiers above are present.
