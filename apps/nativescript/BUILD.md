# Building Everbloom (NativeScript)

All commands run from the project root of a clean checkout. The scripts in
`scripts/` are thin wrappers around the NativeScript CLI (`ns`, installed
locally from `package.json`) and `xcodebuild`.

## Prerequisites

- macOS with Xcode 26 (command line tools selected), an iOS Simulator runtime.
- Node.js and npm.
- The system Ruby (`/usr/bin/ruby`, `/usr/bin/gem`). The NativeScript CLI
  merges xcconfig files with the Ruby `xcodeproj` gem; `scripts/setup.sh`
  installs it into the local `.gems/` directory and the build scripts put a
  `ruby` shim (`scripts/bin/ruby`) first on `PATH` that adds `.gems` to
  `GEM_PATH`. No system gem install is needed.
- CocoaPods installed (the NativeScript CLI's environment check requires it,
  although this project has no pods).
- Android: Android SDK (`ANDROID_HOME`) with platform 36 / build-tools 36,
  a JDK 17+ (`JAVA_HOME`), and an emulator or device for running.

## 1. Install dependencies

```sh
./scripts/setup.sh
```

(This runs `npm ci`, whose `postinstall` applies `patches/` with `patch-package`,
and `gem install --install-dir .gems xcodeproj -v 1.28.1`.)

## 2. iOS device release build (benchmarked)

Signed build with automatic signing:

```sh
DEVELOPMENT_TEAM=XXXXXXXXXX ./scripts/build-ios-device.sh
```

Without `DEVELOPMENT_TEAM` the same command builds with code signing disabled
(`CODE_SIGNING_ALLOWED=NO`):

```sh
./scripts/build-ios-device.sh
```

Result: `build/ios-device/Everbloom.app`

What the script runs:

```sh
PATH="$PWD/scripts/bin:$PATH" npx ns prepare ios --release
PROJ="$(basename platforms/ios/*.xcodeproj .xcodeproj)"   # NativeScript names it after the project directory
xcodebuild -project "platforms/ios/$PROJ.xcodeproj" -scheme "$PROJ" \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios-device \
  -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM build
ditto "build/ios-device/Build/Products/Release-iphoneos/$PROJ.app" build/ios-device/Everbloom.app
```

## 3. Install and launch on a connected iPhone

```sh
xcrun devicectl list devices                      # find the device identifier
DEVICE=<device identifier>
xcrun devicectl device install app --device "$DEVICE" \
  build/ios-device/Everbloom.app
xcrun devicectl device process launch --device "$DEVICE" \
  --environment-variables '{"SHOP_API_URL":"http://192.168.1.20:8787/api"}' \
  dev.whiskerrs.shopbench.nativescript
```

Omit `--environment-variables` to use the default endpoint
(`https://apparel-large-catalog.mock.shop/api`). The app writes
`SHOPBENCH home_ready` to the unified log once Home shows loaded content.

## 4. iOS Simulator build

```sh
./scripts/build-ios-sim.sh
```

Result: `build/ios-sim/Everbloom.app`

Install and launch on the booted simulator:

```sh
xcrun simctl install booted build/ios-sim/Everbloom.app
SIMCTL_CHILD_SHOP_API_URL=http://127.0.0.1:8787/api \
  xcrun simctl launch booted dev.whiskerrs.shopbench.nativescript
```

Watch for the marker:

```sh
xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "SHOPBENCH"'
```

## 5. Android release APK

```sh
./scripts/build-android.sh
```

Result: `build/android/everbloom-release.apk` (release build signed with the
Android debug keystore `~/.android/debug.keystore`; the script creates that
keystore with the standard debug credentials if it does not exist).

The endpoint on Android is a build-time setting. Set `SHOP_API_URL` in the
environment of the build command (it is injected into the bundle by webpack's
DefinePlugin, see `webpack.config.js`):

```sh
SHOP_API_URL=http://192.168.1.20:8787/api ./scripts/build-android.sh
```

(From the Android emulator, the host Mac is `http://10.0.2.2:<port>/api`.)
Without it the default endpoint is used. Install and launch:

```sh
adb install -r build/android/everbloom-release.apk
adb shell am start -n dev.whiskerrs.shopbench.nativescript/com.tns.NativeScriptActivity
```

## 6. Build modes and toolchain

| Target | Mode |
|---|---|
| iOS device | `ns prepare ios --release` (webpack production mode: minified bundle, no dev server/HMR/inspector) + Xcode `Release` configuration, arm64, optimizations on |
| iOS Simulator | Same as device: `ns prepare ios --release` + Xcode `Release` configuration for the simulator SDK. This is the most production-like mode NativeScript supports on the simulator. |
| Android | `ns build android --release` (webpack production mode, Gradle release build), signed with the debug keystore |

The iOS `SHOP_API_URL` launch environment variable is read at startup and takes
priority over any build-time `SHOP_API_URL`.

Toolchain used:

| Tool | Version |
|---|---|
| macOS | 26.5.1 |
| Xcode | 26.6 (17F113), iOS SDK 26.5, Simulator iOS 26.5 (iPhone 17 Pro) |
| Node.js / npm | 26.13.0 / 11.20.0 |
| NativeScript CLI (`nativescript`) | 9.1.2 |
| `@nativescript/core` | 9.1.3 |
| `@nativescript/ios` runtime | 9.1.0 |
| `@nativescript/android` runtime | 9.1.1 |
| `@nativescript/webpack` | 5.0.39 |
| TypeScript | 5.9.3 |
| Ruby (system) / xcodeproj gem | 2.6.10 / 1.28.1 |
| JDK | OpenJDK 21.0.6 (Android Studio JBR) |
| Android | compileSdk/targetSdk 36, build-tools 36, Gradle 8.14.3 (wrapper), emulator image android-36 arm64 |
