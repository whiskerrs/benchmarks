# Building Everbloom (Catalyst)

Run every command from the project root.

The app is a Catalyst React app (`src/`, `client/`, `server/`, `config/`). `npm run bundle` builds it with `catalyst build` and packages it into the native projects. The native projects are small WebView hosts: `ios/` (Swift) and `android/` (Java). They load the bundled app from inside the app package, so there is no dev server and nothing is loaded over the network except API and image requests. NOTES.md explains why the app does not use Catalyst's own native build (`catalyst buildApp:*`).

## 1. Install dependencies

```sh
npm ci
npm run bundle    # catalyst build + package the web app into ios/Everbloom/www and android/app/src/main/assets/www
```

Re-run `npm run bundle` after any change under `src/`, `client/`, `server/` or `config/`. The iOS and Android builds below expect its output.

## 2. iOS device release (benchmarked build)

Signed with automatic signing for your team:

```sh
export DEVELOPMENT_TEAM=ABCDE12345
sh scripts/build-ios.sh device
```

Without `DEVELOPMENT_TEAM` the same command builds unsigned (`CODE_SIGNING_ALLOWED=NO`).

The command it runs:

```sh
xcodebuild -project ios/Everbloom.xcodeproj -scheme Everbloom -configuration Release \
  -sdk iphoneos -destination generic/platform=iOS -derivedDataPath build/ios-device \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build
```

The app is at `build/ios-device/Build/Products/Release-iphoneos/Everbloom.app`.

## 3. Install and launch on a connected iPhone

```sh
xcrun devicectl list devices      # note the device identifier
DEVICE=<identifier>
xcrun devicectl device install app --device "$DEVICE" build/ios-device/Build/Products/Release-iphoneos/Everbloom.app
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing \
  --environment-variables '{"SHOP_API_URL":"http://192.168.1.20:8787/api"}' \
  dev.whiskerrs.shopbench.catalyst
```

Leave out `--environment-variables` to use the default endpoint, `https://apparel-large-catalog.mock.shop/api`. The first request to a LAN address triggers iOS's Local Network permission prompt.

To watch the log marker:

```sh
log stream --device "$DEVICE" --predicate 'eventMessage CONTAINS "SHOPBENCH"'   # or Console.app
```

## 4. iOS Simulator

```sh
sh scripts/build-ios.sh simulator
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install booted build/ios-sim/Build/Products/Release-iphonesimulator/Everbloom.app
SIMCTL_CHILD_SHOP_API_URL=http://192.168.1.20:8787/api xcrun simctl launch booted dev.whiskerrs.shopbench.catalyst
```

The app is at `build/ios-sim/Build/Products/Release-iphonesimulator/Everbloom.app`. Drop `SIMCTL_CHILD_SHOP_API_URL=…` to use the default endpoint. Log marker:

```sh
xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "SHOPBENCH"'
```

Optional: `sh scripts/verify-ios.sh` runs the XCUITest flows in `ios/EverbloomUITests` (Home, Collection to the end, sorts, Product options and recommendations, cart, checkout, search, error and Retry). It runs against the Release simulator build and saves screenshots to `/tmp/eb-shots`.

## 5. Android release APK

```sh
export ANDROID_HOME=$HOME/Library/Android/sdk     # your Android SDK (platform 35, build-tools 35)
(cd android && ./gradlew assembleRelease)
```

The APK is at `android/app/build/outputs/apk/release/app-release.apk`. It is a release build signed with the debug key.

The endpoint is fixed at build time. Pass it as a Gradle property or an environment variable:

```sh
(cd android && ./gradlew assembleRelease -PSHOP_API_URL=http://192.168.1.20:8787/api)
# or
(cd android && SHOP_API_URL=http://192.168.1.20:8787/api ./gradlew assembleRelease)
```

Install and launch on an emulator or phone:

```sh
adb install -r android/app/build/outputs/apk/release/app-release.apk
adb shell am start -n dev.whiskerrs.shopbench.catalyst/.MainActivity
```

## 6. Build modes and toolchain

| Target | Mode |
|---|---|
| Web app | `catalyst build`: Catalyst production build (Vite, minified, `NODE_ENV=production`). Home's server-rendered skeleton is captured once at build time as `index.html`. |
| iOS device | Xcode `Release` configuration: `-O`, whole-module optimisation, arm64, no debugger or Web Inspector. The web app is bundled in the `.app`. |
| iOS Simulator | Xcode `Release` configuration for the simulator SDK. This is the most production-like mode: the same code and bundled web app as the device build. |
| Android | Gradle `release` build type: R8 minify and resource shrinking, signed with the debug key. The web app is bundled in the APK assets. |

Versions used:

| Tool | Version |
|---|---|
| Node.js / npm | 22.23.0 / 10.9.8 |
| catalyst-core | 1.2.1 (with react 19.0.0, react-router 7) |
| Xcode | 26.6 (17F113), iOS 26.5 SDK, simulator iPhone 17 Pro (iOS 26.5) |
| iOS deployment target | 16.0 |
| JDK | OpenJDK 17.0.15 |
| Gradle / Android Gradle Plugin | 8.13 (wrapper) / 8.11.1 |
| Android SDK | compileSdk and targetSdk 35, minSdk 24, build-tools 35.0.0 |
