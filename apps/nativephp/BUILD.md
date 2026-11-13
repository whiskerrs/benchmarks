# Building Everbloom (NativePHP)

All commands run from the project root of a clean checkout, on macOS (Apple silicon).

## Toolchain used

| Tool | Version |
|---|---|
| macOS host PHP / Composer | PHP 8.5.12 (Homebrew), Composer 2.11.2 |
| Laravel | 13.42.0 |
| NativePHP for Mobile (`nativephp/mobile`) | 4.7.0 |
| NativePHP UI components (`nativephp/mobile-ui`) | 0.9.0 |
| NativePHP Browser plugin (`nativephp/mobile-browser`) | 1.2.1 |
| Embedded PHP runtime (downloaded by `native:install`, pinned in `nativephp.lock`, non-ICU) | 8.5.12 |
| Xcode / iOS SDK | Xcode 27.2 (27B52), iOS SDK 27.2 |
| CocoaPods | 1.16.2 |
| iOS Simulator runtime used for verification | iOS 26.5, iPhone 17 Pro |
| JDK | OpenJDK 21.0.6 (Android Studio JBR) |
| Gradle / AGP / Kotlin | 8.14.5 / 8.13.2 / 2.0.0 (from NativePHP's Android template) |
| Android SDK | compileSdk/targetSdk 36, minSdk 33, build-tools 36.0.0 |

Prerequisites: Xcode with an iOS platform installed, CocoaPods (`brew install cocoapods`), PHP ≥ 8.3 with the `zip`
extension and Composer (`brew install php composer`), and the Android SDK at `~/Library/Android/sdk` (or set
`ANDROID_HOME`) with a JDK 17+ on the `PATH` (or `JAVA_HOME` set).

## 1. Install dependencies

```sh
composer install
cp .env.example .env
php artisan key:generate
php artisan native:install both --no-interaction
```

`native:install` generates the native iOS and Android projects in `nativephp/` (git-ignored, regenerated on every
install) and downloads the embedded PHP runtime for both platforms.

## 2. iOS device release build (benchmarked)

Signed build (automatic signing with your team ID):

```sh
DEVELOPMENT_TEAM=XXXXXXXXXX scripts/build-ios.sh device
```

Without `DEVELOPMENT_TEAM` the same command builds with code signing disabled (`CODE_SIGNING_ALLOWED=NO`):

```sh
scripts/build-ios.sh device
```

Resulting app:

```
nativephp/ios/build/Build/Products/Release-iphoneos/NativePHP.app
```

(The executable/bundle file is named `NativePHP.app` by NativePHP's Xcode template; its display name is
`Everbloom` and its bundle identifier is `dev.whiskerrs.shopbench.nativephp`.)

What the script does: `php artisan native:build --release --simulated` configures the generated Xcode project
(bundle id, display name, Info.plist, plugins, icons, CocoaPods/SPM) and stages the Laravel app in release mode
(`composer install --no-dev`, optimized autoloader, maximum zip compression); then it runs
`xcodebuild -scheme NativePHP -configuration Release -sdk iphoneos -destination generic/platform=iOS` (arm64).
Each build gets a unique `CFBundleVersion` (Unix time), because a NativePHP app only re-extracts its bundled code
when the version or build number changes.

## 3. Install and launch on a connected iPhone

```sh
xcrun devicectl list devices
DEVICE=<identifier from the list>
xcrun devicectl device install app --device "$DEVICE" nativephp/ios/build/Build/Products/Release-iphoneos/NativePHP.app
xcrun devicectl device process launch --device "$DEVICE" \
    --environment-variables '{"SHOP_API_URL":"http://192.168.1.20:8787/api"}' \
    dev.whiskerrs.shopbench.nativephp
```

Omit `--environment-variables` to use the default endpoint `https://apparel-large-catalog.mock.shop/api`.
The app reads `SHOP_API_URL` from its process environment at launch (an empty value is ignored).

## 4. iOS Simulator build

```sh
scripts/build-ios.sh simulator
```

Resulting app:

```
nativephp/ios/build/Build/Products/Debug-iphonesimulator/NativePHP-simulator.app
```

Install and launch (booted simulator):

```sh
xcrun simctl install booted nativephp/ios/build/Build/Products/Debug-iphonesimulator/NativePHP-simulator.app
SIMCTL_CHILD_SHOP_API_URL=http://127.0.0.1:8787/api xcrun simctl launch booted dev.whiskerrs.shopbench.nativephp
```

Watch the readiness marker:

```sh
xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "SHOPBENCH"'
```

## 5. Android release APK

```sh
scripts/build-android.sh
```

Resulting APK (release build, signed with the Android debug key `~/.android/debug.keystore`, created if missing):

```
nativephp/android/app/build/outputs/apk/release/app-release.apk
```

Install and launch:

```sh
adb install -r -d nativephp/android/app/build/outputs/apk/release/app-release.apk
adb shell am start -n dev.whiskerrs.shopbench.nativephp/com.nativephp.mobile.ui.MainActivity
```

Endpoint: Android reads `SHOP_API_URL` at build time. Pass it to the build script, which writes it into the
bundled app's `.env` for that build only:

```sh
SHOP_API_URL=http://192.168.1.20:8787/api scripts/build-android.sh
```

(Alternatively set `SHOP_API_URL=...` in `.env` before building.) Plain HTTP is allowed on both platforms. The
readiness marker goes to logcat: `adb logcat -s SHOPBENCH`.

## 6. Build modes

| Target | Mode |
|---|---|
| iOS device (benchmarked) | Xcode **Release** configuration, arm64 `iphoneos`, optimizations on (Swift `-O`, whole module); Laravel bundle staged in NativePHP release mode (`--no-dev`, `APP_ENV=production`, `APP_DEBUG=false`). No dev server, no hot reload (NativePHP's hot-reload server is compiled only into Debug builds), no FPS/debug overlays. Only API and image requests touch the network. |
| iOS Simulator (verification) | The most production-like mode NativePHP supports on the simulator: the Laravel bundle is staged in **release** mode (`native:build --release --simulated`), compiled with NativePHP's `NativePHP-simulator` scheme, which always uses Xcode's **Debug** configuration (arm64 simulator). No dev server is started; the app runs fully from its bundle. |
| Android | Gradle `assembleRelease` (NativePHP `native:package --build-type=release`), signed with the debug keystore; Laravel bundle in release mode. R8 minification is off (NativePHP default). |
