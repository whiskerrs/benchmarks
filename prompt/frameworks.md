# Framework variables

`PROMPT.md` is a template. Substitute these three values, apply the variant if the row has one, and change nothing else.

| `{{FRAMEWORK_NAME}}` | `{{FRAMEWORK_REPO}}` | `{{APP_ID_SUFFIX}}` | Output directory | Variant |
|---|---|---|---|---|
| React Native | https://github.com/facebook/react-native | `reactnative` | `apps/react-native/` | |
| Flutter | https://github.com/flutter/flutter | `flutter` | `apps/flutter/` | |
| Whisker | https://github.com/whiskerrs/whisker | `whisker` | `apps/whisker/` | |
| Native Shell | https://github.com/longbridge/nsh | `nsh` | `apps/nsh/` | |
| NativeScript | https://github.com/NativeScript/NativeScript | `nativescript` | `apps/nativescript/` | |
| Exact | https://github.com/expo/exact | `exact` | `apps/exact/` | |
| UIKit | https://developer.apple.com/documentation/uikit | `uikit` | `apps/uikit/` | `ios-only` |
| SwiftUI | https://developer.apple.com/documentation/swiftui | `swiftui` | `apps/swiftui/` | `ios-only` |
| DartNative | https://github.com/DartNative/dartnative | `dartnative` | `apps/dartnative/` | |
| NativePHP | https://github.com/nativephp/mobile-air | `nativephp` | `apps/nativephp/` | `webview` |

## Variants

A variant edits `PROMPT.md` for a framework that cannot meet it as written. The exact edits are `VARIANTS` in `tools/ai_run.py`.

| Variant | Change | Effect on comparisons |
|---|---|---|
| `ios-only` | Drops every Android requirement (build, endpoint setting, emulator check). | The AI run does no Android work, so its cost, time, and turns are not comparable with the two-platform runs. |
| `webview` | Drops the ban on WebViews. | None in practice: the NativePHP run used NativePHP 4, which renders with SwiftUI and Compose, and no screen is a WebView. |
