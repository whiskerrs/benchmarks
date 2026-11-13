# Building Everbloom (SwiftUI)

All commands run from the project root.

## Toolchain

| Tool | Version |
|---|---|
| Xcode | 27.2 (27B52) |
| Swift | 6.4.2 (compiled in Swift 5 language mode) |
| iOS SDK | 27.2 (device and simulator) |
| macOS | 27.2.1 |
| Deployment target | iOS 18.0 |
| XcodeGen (optional, only to regenerate the project) | 2.45.4 |

## 1. Install dependencies

Nothing to install beyond Xcode: the app uses only Apple frameworks (SwiftUI, Foundation, SafariServices, os), and
`Everbloom.xcodeproj` is checked in.

The project was generated from `project.yml` with XcodeGen. You only need XcodeGen if you change `project.yml`:

```sh
brew install xcodegen   # optional
xcodegen generate       # optional, rewrites Everbloom.xcodeproj
```

## 2. iOS device release build (benchmarked)

Build mode: **Release** configuration (`-O`, whole-module optimization), arm64, `generic/platform=iOS`.

Signed, with automatic signing for the team in `DEVELOPMENT_TEAM`:

```sh
export DEVELOPMENT_TEAM=XXXXXXXXXX   # your Apple team ID
xcodebuild -project Everbloom.xcodeproj -scheme Everbloom -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  build
```

Without a team (code signing disabled):

```sh
xcodebuild -project Everbloom.xcodeproj -scheme Everbloom -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Resulting app: `build/Build/Products/Release-iphoneos/Everbloom.app`

## 3. Install and launch on a connected iPhone

```sh
xcrun devicectl list devices                      # find the device identifier
DEVICE=<device identifier>
xcrun devicectl device install app --device "$DEVICE" build/Build/Products/Release-iphoneos/Everbloom.app
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing \
  --environment-variables '{"SHOP_API_URL":"http://192.168.1.20:8787/api"}' \
  dev.whiskerrs.shopbench.swiftui
```

Leave out `--environment-variables` to use the default endpoint (`https://apparel-large-catalog.mock.shop/api`).

## 4. iOS Simulator build (verification)

Build mode: **Release** configuration (same optimized settings as the device build), simulator SDK, unsigned. This is the
most production-like mode available on the simulator; SwiftUI has no separate production mode.

```sh
xcodebuild -project Everbloom.xcodeproj -scheme Everbloom -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build \
  build
```

Resulting app: `build/Build/Products/Release-iphonesimulator/Everbloom.app`

Install and launch on a booted simulator:

```sh
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true   # any iPhone simulator
xcrun simctl install booted build/Build/Products/Release-iphonesimulator/Everbloom.app
SIMCTL_CHILD_SHOP_API_URL=http://127.0.0.1:8787/api \
  xcrun simctl launch --terminate-running-process booted dev.whiskerrs.shopbench.swiftui
```

Watch for the readiness marker:

```sh
xcrun simctl spawn booted log stream --style compact --predicate 'eventMessage CONTAINS "SHOPBENCH"'
```

## 5. Build modes summary

| Target | Configuration | Notes |
|---|---|---|
| iOS device (benchmarked) | Release | arm64, `-O`, whole module, dSYM, automatic signing with `DEVELOPMENT_TEAM` or `CODE_SIGNING_ALLOWED=NO` |
| iOS Simulator | Release | same optimization settings, simulator SDK |

## Optional: UI verification tests

`EverbloomUITests` is an XCUITest target used only to verify the flows and accessibility identifiers on the simulator.
It is not part of the app build above.

```sh
xcodebuild test -project Everbloom.xcodeproj -scheme Everbloom \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build-test \
  -skip-testing:EverbloomUITests/EverbloomUITests/testErrorState
```

`testErrorState` expects the app to point at an unreachable endpoint. Run it with
`TEST_RUNNER_TEST_SHOP_API_URL=http://10.255.255.1:9/api` set.
