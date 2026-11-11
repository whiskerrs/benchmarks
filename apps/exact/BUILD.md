# Building Everbloom (Exact)

All commands run from the project root on macOS (Apple silicon). The app is in `everbloom/`;
Exact itself is cloned into `vendor/exact2/` by step 1 (Exact has no releases: an app builds
against a checkout, by path).

> **iOS needs Xcode 27.** The pinned Exact commit (and every public Exact commit) compiles its
> UIKit host against the iOS 27 SDK (`UIArrangementViewController`, iOS 27 `AVAudioSession`
> notifications and other iOS 27 APIs). With Xcode 26.x the Swift compile of `ExactKit` fails.
> If Xcode 27 is not `xcode-select`'s, point the commands at it:
> `export DEVELOPER_DIR=/Applications/Xcode-27.app/Contents/Developer`.

## 1. Install dependencies

Prerequisites: Xcode 27 (with an iOS 27 Simulator runtime), `rustup`, `git`, `curl`, and for
Android the Android SDK (`ANDROID_HOME`, default `~/Library/Android/sdk`) with an NDK and a JDK 17+
(Android Studio's bundled JBR is picked up automatically).

```sh
scripts/install.sh
```

It clones Exact (`expo/exact` at `fc14919528fb76ca8de3e8c8d9ef91853f923a17`) and Ibex
(`expo/ibex` at `a0183568e8229b8243629cdb26cd4a88ac4e2abd`) into `vendor/`, installs Bun 1.4.2
into `~/.bun-1.4.2` (beside any other Bun), runs Exact's `setup` (pinned Rust 1.97.0, Hermes
bundles for macOS and iOS, offline crates), adds the Rust targets `aarch64-apple-ios`,
`aarch64-apple-ios-sim` and `aarch64-linux-android`, installs the app's package
(`@exact/in-app-browser`, from the Exact checkout), and builds the Android Hermes bundle from
the Ibex checkout (about 10 minutes, once; cached in `~/.cache/exact/hermes-android`). For Android
it also needs the SDK platform 37.2:

```sh
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "platforms;android-37.2"
```

## 2. iOS device release build (benchmarked)

Signed for a team (automatic signing; Xcode must be signed in to an account of that team, and the
iPhone must have been connected to this Mac at least once so `xcrun devicectl list devices` lists it;
with several phones, `EXACT_PHONE=<udid or name>` picks one):

```sh
DEVELOPMENT_TEAM=ABCDE12345 scripts/build-ios-device.sh
```

Without a team (code signing disabled: ad-hoc signed, no profile, no team):

```sh
scripts/build-ios-device.sh
```

Result: **`build/ios-device/Everbloom.app`**.

Exact builds the `.app` itself (Cargo, SwiftPM, its own bundler and `codesign`), not through an
Xcode project. With `DEVELOPMENT_TEAM` set, the script first builds a never-shipped stub Xcode
project (`scripts/signing-stub/`) with the same bundle id, `-allowProvisioningUpdates` and
`-allowProvisioningDeviceRegistration`, so Xcode's automatic signing creates the team's development
profile (registering a connected phone), then runs Exact's device release build signed with that
profile and the team's Apple Development identity
(`bun exact.mjs ios --device --release --no-install` with `EXACT_PROFILE`/`EXACT_IDENTITY`).
Without a team it runs Exact's phone-less device packaging, `ios --device --release --archive … --unsigned`
(also `build/ios-device/Everbloom.ipa`). That path is Exact's distribution packaging and refuses a
bundle without an app icon, so for this build only the script names a plain white placeholder icon
(`scripts/unsigned-placeholder-icon.png`) in `app.json` and restores `app.json` afterwards; the
signed build has no icon. The first build takes 10–15 minutes.

## 3. Install and launch on a connected iPhone

```sh
xcrun devicectl list devices          # note the phone's Identifier
DEVICE=<the phone's identifier or name>
xcrun devicectl device install app --device "$DEVICE" build/ios-device/Everbloom.app
xcrun devicectl device process launch --device "$DEVICE" \
  --environment-variables '{"SHOP_API_URL":"http://192.168.1.20:8787/api"}' \
  dev.whiskerrs.shopbench.exact
```

Omit `--environment-variables` to use `https://apparel-large-catalog.mock.shop/api`. The app reads
`SHOP_API_URL` from its launch environment (through its Swift module, `everbloom/modules/apple/Shop.swift`).

## 4. iOS Simulator build

Boot an iPhone simulator first (`xcrun simctl boot "iPhone 17 Pro"`; or set `EXACT_SIM` to a
name or UDID). Then:

```sh
scripts/build-ios-simulator.sh
```

Result: **`build/ios-simulator/Everbloom.app`** (the script also installs it on the booted simulator).
Install and launch with the endpoint override:

```sh
xcrun simctl install booted build/ios-simulator/Everbloom.app
SIMCTL_CHILD_SHOP_API_URL=http://127.0.0.1:8787/api xcrun simctl launch booted dev.whiskerrs.shopbench.exact
```

The marker line: `xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "SHOPBENCH"'`.

`scripts/dev-proxy.ts` (`~/.bun-1.4.2/bin/bun scripts/dev-proxy.ts 8787`) is a stand-in for the replay
server that forwards to mock.shop; stop it to see the error state, start it again and tap Retry.

## 5. Android release APK

```sh
scripts/build-android.sh                                            # default endpoint
SHOP_API_URL=http://192.168.1.20:8787/api scripts/build-android.sh  # endpoint fixed at build time
```

Result: **`build/android/Everbloom-release.apk`** (`everbloom/target/android/app/outputs/apk/release/app-release.apk`).

```sh
adb install -r build/android/Everbloom-release.apk
adb shell am start -n dev.whiskerrs.shopbench.exact/dev.exact.app.MainActivity
```

The endpoint is read at build time (`app.json` `env`: `SHOP_API_URL` from the environment, else
`everbloom/.env.local`, else `everbloom/.env`) and inlined into the data module. Plain HTTP is
allowed: Exact's `fetch` on Android uses its own Rust sockets, which Android's cleartext policy does
not govern, and the app's grants admit `http:` and `https:` to any host.

## 6. Build modes and toolchains

| Build | Mode |
|---|---|
| iOS device | Exact production: `ios --device --release` (signed; `--archive --unsigned` without a team) (Rust `release` profile, Swift whole-module `-O`, `EXACT_UPDATE_TRUST=production`, plan and Hermes bytecode baked in, no development server, no agent, no hot reload, no dev menu; update store `"0"`, so no update checks) |
| iOS Simulator | The same production mode for the simulator: `ios --release` (Exact's "build that ships", the most production-like it offers on the simulator) |
| Android | Rust `release` profile (fat LTO) + Gradle `assembleRelease`, signed with the debug key |

| Tool | Version |
|---|---|
| Exact | `expo/exact` `fc14919528fb76ca8de3e8c8d9ef91853f923a17` (2026-11-10) |
| Bun | 1.4.2 (pinned by Exact) |
| Rust | 1.97.0 (pinned by Exact's `rust-toolchain.toml`) |
| Hermes | 260318099.0.4 (Ibex bundle `hermes-vanilla-d412d3bd8512-v5`; Android built from Ibex `a0183568`) |
| Xcode | 27.2 (27B52), iOS SDK 27.2; verified on the iOS 27.2 Simulator (iPhone 17 Pro). Xcode 26.x cannot build Exact |
| Android | SDK platform 37.2, NDK 29.0.14206865, Gradle 9.8.0 (wrapper), JDK 21 (Android Studio JBR), CMake 3.22.1 (SDK) for Hermes |
| macOS | 27.2.1 |
