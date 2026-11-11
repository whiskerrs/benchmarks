# Xcode 27 rebuild

On 2026-11-10 the Mac moved from Xcode 26.6 to Xcode 27.2 (needed by Exact), and the five other apps' simulator builds were rebuilt with their own BUILD.md commands. Logs: `rebuild-<app>.log`.

| App | Result | Change made by hand |
|---|---|---|
| React Native | builds | none |
| Flutter | failed twice, then builds | Deployment target 13.0 → 15.0 (`ios/Podfile`, `Runner.xcodeproj`): Xcode 27 supports 15.0 and later. `EXCLUDED_ARCHS[sdk=iphonesimulator*]=x86_64` in `ios/Flutter/{Debug,Release}.xcconfig`: Flutter 3.35.7 calls `lipo -verify_arch arm64 x86_64`, which Xcode 27's `lipo` rejects. |
| Whisker | builds | none |
| Native Shell | builds | none |
| NativeScript | failed, then builds | none in the app: the NativeScript CLI's CocoaPods check fails when `LANG` is unset, so builds run with `LANG=en_US.UTF-8`. |

## iOS 27.2 runtime

Apps linked against the iOS 27 SDK must adopt the UIScene lifecycle, or they stop at launch in `_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`. Flutter 3.35.7 predates Flutter's UIScene support, so the Flutter app moved to Flutter 3.47.9 (`.fvmrc`) and to its scene-based entry point: `AppDelegate` adopts `FlutterImplicitEngineDelegate` and registers plugins and the `shopbench/native` channel in `didInitializeImplicitFlutterEngine`, and `Info.plist` declares a `UIApplicationSceneManifest` with `FlutterSceneDelegate`. A copy installed over the pre-migration build opened to a black screen; a fresh install renders, so validation always uninstalls first. Whisker got the same fix in whisker-cng 0.17.0 (whiskerrs/whisker#797): the app moved from whisker 0.16 to 0.17 (packages 0.14.4–0.14.5, CLI 0.17.0), and `shop-native/Package.swift`'s SDK pin from 0.1.19 to 0.1.20 to match the packages.

## NativeScript app fix

The journey stopped at `missing tab-search` in the cart phase: after Add to cart the Cart tab opened without the tab bar. Pages call `reportPage(page.frame, …)` from `navigatingTo`, before the page is attached, so `page.frame` is `undefined` and `frames[t] === undefined` matched the first tab without a frame yet (Cart), marking it as a tab-bar-hiding Product stack. `app/lib/nav.ts` now returns early when `frame` is undefined. This is a hand fix to the AI's app code, made on 2026-11-11 after the run, and is counted as a D5 failure of the original build (the tab bar disappears on Cart), not as a D4 intervention in the AI run.

These are toolchain fixes, not AI work; they are not counted as interventions in D4.
