# Notes

Everbloom, built with DartNative 1.6.0 (`dn` CLI, UIKit / Android Views
driven from Dart). Build commands are in `BUILD.md`.

## Blocker: DartNative needs a paid licence to run this app

DartNative checks a licence inside `runApp()`. Without a subscriber key, the
free trial token that `dn` injects only unlocks the official demos (the
DartNative playground, tutorials and plugin examples, identified by their
bundle ids). Any other bundle id, including
`dev.whiskerrs.shopbench.dartnative`, shows a full-screen "DartNative
License - This app is not an official Dart Native demo ... subscribe at
dartpub.dev" card instead of the app's UI, on the simulator, on devices and on
Android alike.

No licence key was available in this environment and buying a subscription
was out of scope, and running the app under a demo bundle id or patching the
check would mean working around the licence (and modifying DartNative, which
the spec forbids). So:

- Every build in `BUILD.md` compiles and links (iOS device release, iOS
  simulator, Android release APK), and the Dart code passes `dn analyze`.
- The logic that can run off-device (GraphQL documents vs. the spec, money
  formatting, image URLs, variant selection, response parsing) is covered by
  `dn test` (`test/models_test.dart`).
- **Nothing in the UI could be exercised at runtime.** On the simulator the
  app shows the licence card. The "Done" items that need the running app
  (navigating the screens, `SHOPBENCH home_ready` in the log, the
  accessibility identifiers in XCUITest, the error/retry check, Android Home
  loading) are unverified.

To run it, configure a DartNative licence key before building:

```sh
dn config --license-key dnk_...
```

or add `--dart-define=DN_LICENSE_KEY=dnk_...` to every `dn build` command
in `BUILD.md`. `scripts/build-ios-device.sh` picks the configured key up
automatically (it runs `dn build ios --config-only`, which writes the key
into the Xcode build's Dart defines).

## Decisions where the spec is silent

- **Navigation.** DartNative's `Navigator` is one native stack for the whole
  app, so a pushed route covers the tab bar and cannot keep a stack per tab.
  The app keeps one stack per tab in Dart (`lib/state/app_state.dart`) and
  shows the top screen of the selected tab; every screen of every stack stays
  mounted (`IndexedStack`), so switching tabs or going back keeps state and
  scroll positions. Pushes and pops have no transition animation and there is
  no edge-swipe back on iOS; the back buttons and Android's system back
  (through `PopScope`) pop the current tab's stack.
- **Tab bar.** Drawn from DartNative widgets (`Row`, `Container`,
  `CustomPaint`) instead of `BottomNavigationBar`, because the native tab bar
  only takes font glyph icons (the design's icons would need a bundled icon
  font) and renders as the iOS 26+ floating glass pill rather than the
  design's white bar. It is shown on Home, Collection, Search and Cart and
  hidden while a Product screen is on top.
- **Icons.** The design's SVG paths (home, search, cart, back, plus the
  stepper minus/plus and the error-state alert circle) are drawn as vector
  paths with `CustomPaint`.
- **"See all"** next to the Collections heading on Home is in the mockup but
  not in the spec and has no defined target; it is left out.
- **Empty cart** shows the States design's "Start shopping" button, which
  switches to the Home tab.
- **Product back button** floats over the top-left of the screen (it does not
  scroll away with the carousel), so it is always reachable.
- **Page dots** show the current image; they are not tappable (the carousel
  is swiped). Dots are hidden when a product has a single image.
- **Option selection.** Tapping a pill keeps the other selected options and
  changes that one; if no variant has that exact combination, the first
  variant with the tapped value is selected.
- **Prices.** Product cards (Home best sellers, Collection grid) and the
  product price show the sale colour plus the struck-through compare-at
  price when it is higher. Search rows and recommendation cards show the
  price only, as in the design.
- **Variables.** `after` is omitted from the variables of the first page of
  `CollectionProducts` / `Search` (it is optional) and set to `endCursor` for
  later pages. The search query is sent trimmed.
- **Infinite scroll errors.** A failed first page shows the error state with
  Retry. A failed later page stops the spinner; scrolling near the end again
  retries it.
- **Cart errors.** `userErrors` show the first message in an alert. A
  network or server failure of a cart operation shows an alert "Couldn't add
  to cart" / "Couldn't update cart". Add to cart switches to the Cart tab only
  when the operation succeeds without user errors.
- **Stepper.** While a cart operation is in flight, further stepper taps are
  ignored, so operations never race.
- **Loading states.** Home shows the skeleton from the States design;
  Collection, Search and Product show a small spinner or skeleton while their
  first request runs; all show the shared error state with Retry.
- **HTTP.** Requests time out after 20 s; HTTP caching and cookies are off.
- **Image placeholder.** Every image sits on a `surface`-coloured box, which
  shows until the image loads (and stays if it fails).
- **App icon.** None: the template's icon set was removed. On Android the
  launcher shows the system default icon.
- **Android 12+ splash** is plain white with no icon.

## Dependencies added

All are DartNative's own first-party plugins:

- `dartnative_http` - HTTP client on NSURLSession / OkHttp, used for the
  GraphQL POSTs (plain HTTP, no GraphQL client).
- `dartnative_url_launcher` - opens the checkout URL. DartNative has no in-app
  browser component (only a WebView widget, which the spec rules out for
  screens), so checkout opens in the system browser.

(`package:http`, `package:web_socket` and similar come in transitively with
`dartnative_http`.)

## Not met, or met differently

- **Runtime verification** of everything: see the licence blocker above.
- **Android test tags / resource-ids are not set.** DartNative exposes no
  test-id API. On iOS the identifiers are set from Dart through the
  Objective-C runtime on the native view that DartNative's view registry
  returns for a widget (`lib/native/native_bridge.dart`, `AxId` in
  `lib/ui/widgets.dart`). Android would need a JNI bridge into the app's
  Kotlin code, which was not built; the benchmark only drives iOS.
- **`SHOPBENCH home_ready`** is written with `NSLog` (called through FFI),
  because DartNative release builds drop `print` output. It is written once
  per process, after the first frame that shows loaded Home content. On
  Android nothing is logged.
- **Simulator build mode.** DartNative only supports debug mode on the iOS
  Simulator ("Release/Profile mode is not supported for simulators"), so the
  simulator app is a debug (JIT) build; it is self-contained and needs no dev
  server. The device build is release (AOT).
- **No iOS edge-swipe back and no push animation**, a consequence of the
  per-tab stacks above.
