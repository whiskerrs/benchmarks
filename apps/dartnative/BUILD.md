# Build

All commands run from the project root on a clean checkout, in zsh/bash on
macOS.

> **Licence first.** DartNative refuses to run any app that is not one of
> its official demos unless the build carries a DartNative licence key (see
> `NOTES.md`). Without a key every build below still succeeds, but the app
> shows DartNative's licence card instead of Everbloom.

## 1. Install dependencies

Toolchain: Xcode 26.3 or newer with an iOS platform installed, CocoaPods,
Android SDK 36 (platform + build-tools) with an NDK, JDK 17+.

```sh
# DartNative CLI (dn) into ~/zero; then put it on PATH for this shell
curl -fsSL https://cdn.dartnative.com/install.sh | sh
export PATH="$PATH:$HOME/zero/bin"
dn --version                              # first run downloads the engine

# DartNative licence key (needed for the app to run, see above)
dn config --license-key dnk_...

# Dart and plugin packages
dn pub get
```

`dn` runs `pod install` and Gradle itself during the builds below.

Optional check of the off-device logic: `dn test`.

## 2. iOS device release (signed)

```sh
DEVELOPMENT_TEAM=ABCDE12345 scripts/build-ios-device.sh
```

Result: `build/ios-device/Build/Products/Release-iphoneos/Runner.app`

The script runs `dn build ios --release --config-only` (writes the Xcode
configuration, Dart defines and licence) and then `xcodebuild` for the
`Runner` scheme, `Release` configuration, `generic/platform=iOS` (arm64),
with automatic signing for `$DEVELOPMENT_TEAM`.

Without `DEVELOPMENT_TEAM` the same command builds with code signing
disabled (`CODE_SIGNING_ALLOWED=NO`), to the same path:

```sh
scripts/build-ios-device.sh
```

## 3. Install and launch on a connected iPhone

```sh
xcrun devicectl list devices              # note the device identifier
DEVICE=<device identifier>

xcrun devicectl device install app --device "$DEVICE" \
  build/ios-device/Build/Products/Release-iphoneos/Runner.app

xcrun devicectl device process launch --device "$DEVICE" \
  --environment-variables '{"SHOP_API_URL":"http://192.168.1.20:8787/api"}' \
  dev.whiskerrs.shopbench.dartnative
```

Leave out `--environment-variables` to use the default endpoint
(`https://apparel-large-catalog.mock.shop/api`).

## 4. iOS Simulator

```sh
dn build ios --simulator --debug
```

Result: `build/ios/iphonesimulator/Runner.app`

```sh
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
SIMCTL_CHILD_SHOP_API_URL=http://127.0.0.1:8787/api \
  xcrun simctl launch booted dev.whiskerrs.shopbench.dartnative

# the launch marker
xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "SHOPBENCH"'
```

Leave out `SIMCTL_CHILD_SHOP_API_URL=...` to use the default endpoint.

## 5. Android release APK

```sh
dn build apk --release
```

Result: `build/app/outputs/dn-apk/app-release.apk` (signed with the
debug key).

The endpoint is a build-time setting on Android:

```sh
dn build apk --release --dart-define=SHOP_API_URL=http://10.0.2.2:8787/api
```

(`10.0.2.2` is the host machine as seen from the Android emulator.) Install
and launch:

```sh
adb install -r build/app/outputs/dn-apk/app-release.apk
adb shell am start -n dev.whiskerrs.shopbench.dartnative/.MainActivity
```

## 6. Build modes and toolchain

| Build | Mode |
|---|---|
| iOS device | Release: Dart AOT, optimisations on, no dev server or hot reload, arm64 |
| iOS Simulator | Debug (JIT), self-contained, no dev server needed. DartNative supports only debug mode on the simulator: `--release` and `--profile` fail with "Release mode is not supported for simulators". |
| Android | Release APK: Dart AOT, debug-key signing |

Versions used:

- DartNative 1.6.0 (`dn` framework revision b33b3be79eb, engine ed0d71411e),
  Dart 3.12.0-192.0.dev (bundled with `dn`)
- Plugins: dartnative_http 1.1.0, dartnative_url_launcher 1.0.1
  (`dn_plugins.lock`)
- Xcode 27.2 (27B52), iOS Simulator runtime 27.2, CocoaPods 1.16.2,
  macOS 27.2.1
- Android SDK platform 36, build-tools 36.0.0, NDK 28.2.13676358,
  Android Gradle Plugin 8.11.1, Kotlin 2.2.20, OpenJDK 21.0.6
