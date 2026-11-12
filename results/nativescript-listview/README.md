# NativeScript ListView fix

Both NativeScript AI runs (`results/ai-runs-nativescript/`) crashed in the iOS `ListView` and worked around it in the app. The cause is in `@nativescript/core`: `ListViewCell.willMoveToSuperview(nil)` tore down a cell's item view whenever UIKit took the cell out of the table (on `reloadData`, after every sort change or `ObservableArray` splice), and `_prepareCell` rebuilt it when the cell was reused. In release builds that rebuild either aborts (`-[DictionaryAdapter CGColor]` or `_resolvedMaterialWithTraitCollection:` unrecognized selector, then UIKit's nil-cell assertion in `_createPreparedCellForGlobalRow`) or leaves the screen no longer redrawing. The fix removes that teardown (NativeScript/NativeScript#11637); until it is released, the app applies the same change to `@nativescript/core` 9.1.3 with `patch-package`.

## Changes to the app

Hand changes to the AI's app code, made on 2026-11-12 after the runs; not AI work and not counted in D4.

- `patches/@nativescript+core+9.1.3.patch`, applied by `patch-package` on `npm ci` (`postinstall`); `patch-package` is a dev dependency.
- The workarounds for the crash are removed:
  - the override of the private `ListView._removeContainer` in `app/lib/paged-list.ts`;
  - native styling of list images in their `loaded` event (`app/lib/grid.ts`, removed): images use the `.img` class like the rest of the app;
  - filling rows imperatively in `itemLoading`: the Collection grid, Search results and Home's Best sellers use `{{ }}` bindings in their templates, with `itemTemplateSelector` and `rowHeight` set in XML.
- `NOTES.md` and `BUILD.md` describe the patch.

Paging by scroll position, the fixed row heights and the accessibility settings inside cells are unchanged.

## Verification

iOS 26.5 Simulator (iPhone 17 Pro), Release builds, `@nativescript/ios` 9.1.1, driven with Maestro. The stress flow opens the first collection, then three times scrolls the grid down and up and taps the four sort chips in a row, then checks that `product-card-0` is visible.

| Build | Stress flow |
|---|---|
| App as built by the AI, `_removeContainer` override removed | crashed 6 / 6 (nil-cell abort) |
| App as built by the AI | passed 4 / 4 |
| This change without the core patch | no crash; the screen stopped redrawing in 8 / 10 |
| This change | passed 10 / 10 |

A flow through Home, Search (scrolled past the first page), Product, Add to cart, the Cart stepper and badge, and back to Home's Best sellers passes on this change and on the AI's build.

Not measured here: the device metrics. The same-session device comparison for `@nativescript/ios` 9.1.1 is in #1; this change should be re-measured with the rest of the apps.
