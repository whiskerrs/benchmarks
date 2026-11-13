# Building Everbloom (UIKit)

All commands run from the project root. The Xcode project (`Everbloom.xcodeproj`) is checked in. It was
generated from `project.yml` with XcodeGen, but you do not need XcodeGen to build.

## 1. Install dependencies

There are none. The app uses only Apple frameworks (UIKit, Foundation, SafariServices, os).
You need Xcode 27.2 with the iOS 27.2 SDK and an iOS simulator runtime.

(Optional, only if you edit `project.yml`: `brew install xcodegen && xcodegen generate`.)

## 2. iOS device release build (benchmarked)

Signed, with automatic signing and the team from `DEVELOPMENT_TEAM`:

```sh
xcodebuild -project Everbloom.xcodeproj -scheme Everbloom -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  build
```

Without a team, with code signing disabled:

```sh
xcodebuild -project Everbloom.xcodeproj -scheme Everbloom -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Resulting app: `build/Build/Products/Release-iphoneos/Everbloom.app`

## 3. Install and launch on a connected iPhone

```sh
# Find the device identifier
xcrun devicectl list devices

DEVICE=<device identifier>
xcrun devicectl device install app --device "$DEVICE" build/Build/Products/Release-iphoneos/Everbloom.app
xcrun devicectl device process launch --device "$DEVICE" \
  --environment-variables '{"SHOP_API_URL":"http://192.168.1.20:8787/api"}' \
  dev.whiskerrs.shopbench.uikit
```

Leave out `--environment-variables` to use the default endpoint (`https://apparel-large-catalog.mock.shop/api`).
On first launch against a local-network address, iOS asks for Local Network permission. Allow it.

## 4. iOS Simulator build

```sh
xcodebuild -project Everbloom.xcodeproj -scheme Everbloom -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build \
  build
```

Resulting app: `build/Build/Products/Release-iphonesimulator/Everbloom.app`

Install and launch on a booted simulator:

```sh
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install booted build/Build/Products/Release-iphonesimulator/Everbloom.app
SIMCTL_CHILD_SHOP_API_URL="http://127.0.0.1:8787/api" \
  xcrun simctl launch --terminate-running-process booted dev.whiskerrs.shopbench.uikit
```

Watch for the readiness marker:

```sh
xcrun simctl spawn booted log stream --style compact --predicate 'eventMessage CONTAINS "SHOPBENCH"'
```

## 5. Build modes and toolchain

| Build | Configuration |
|---|---|
| iOS device | `Release`: `-O` with whole-module optimization, arm64, no debugger attached, no debug overlays |
| iOS Simulator | `Release`, the same optimized configuration built for the simulator. This is the most production-like mode UIKit supports on the simulator. |

Toolchain used:

- macOS 27.2.1
- Xcode 27.2 (27B52), iOS SDK 27.2, iOS Simulator SDK 27.2
- Apple Swift 6.4.2 (Swift 5 language mode)
- Deployment target: iOS 17.0
- XcodeGen 2.45.4 (used only to generate the checked-in project)

## Optional: UI flow tests (simulator)

`EverbloomUITests` is an XCUITest target used to verify the flows and identifiers. It is not part of the app build.

```sh
xcodebuild test -project Everbloom.xcodeproj -scheme Everbloom \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build \
  -skip-testing:EverbloomUITests/FlowTests/testErrorAndRetry \
  -skip-testing:EverbloomUITests/FlowTests/testFastReplayCollections \
  -skip-testing:EverbloomUITests/FlowTests/testFastReplaySearch
```

`testFastReplayCollections` and `testFastReplaySearch` launch the app with `SHOP_API_URL=http://127.0.0.1:8787/api` and
expect a fast (caching) replay server there. They are regression tests for pages arriving faster than the list lays out.

`testErrorAndRetry` expects nothing to be listening on `127.0.0.1:8799` at launch, and then a forwarding proxy to
mock.shop to start on that port while the test is running.
