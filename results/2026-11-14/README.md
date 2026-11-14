# Results: 2026-11-14

Whisker and NativeScript re-measured on the same iPhone 12 (iOS 27.2) with the same protocol as `results/2026-11-11/`, after a framework update for each:

- **Whisker** 0.17.0 → 0.18.1, which includes performance work found with this benchmark (whiskerrs/whisker#843). The benchmark is maintained by Whisker's authors.
- **NativeScript** `@nativescript/core` 9.1.3 → 9.1.4, plus a hand change to the app's `ListView` workaround that PR #2 traced the 1.7 GB peak to (see "NativeScript").

## Summary

Median, with the interquartile range in parentheses, pooled over both rounds. The 2026-11-11 values are from `results/2026-11-11/summary.json`.

| Metric | Whisker 0.17.0 (11-11) | Whisker 0.18.1 | NativeScript (11-11) | NativeScript (this run) |
|---|---|---|---|---|
| L1 launch → first frame (ms) | 154 (151–155) | 118 (117–118) | 226 (225–229) | 229 (227–237) |
| L2 launch → content (ms) | 166 (165–211) | 142 (136–153) | 373 (333–375) | 357 (303–371) |
| M1 memory after launch (MB) | 93 (92–94) | 23 (22–24) | 85 (84–87) | 86 (85–87) |
| M2 peak memory (MB) | 375 (371–383) | 53 (52–57) | 1706 (1694–1716) | 168 (167–169) |
| M3 memory after journey (MB) | 346 (343–348) | 51 (50–51) | 382 (354–386) | 146 (145–147) |
| C1 CPU time over journey (s) | 85.3 (84.8–85.6) | 63.8 (63.7–64.1) | 105.3 (103.5–105.4) | 104.0 (103.6–105.0) |
| C2 avg CPU while scrolling (%) | 16.2 (15.9–16.5) | 13.2 (13.1–13.2) | 19.9 (19.8–20.2) | 20.3 (20.0–20.4) |
| C2 peak CPU while scrolling (%) | 41 (40–47) | 38 (37–41) | 71 (65–75) | 88 (83–94) |
| N1 requests per journey | 41 (41–206) | 41 (41–206) | 716 (689–732) | 698 (685–745) |
| N1 MB per journey | 0.3 (0.3–5.7) | 0.3 (0.3–5.7) | 24.3 (24.0–24.7) | 23.9 (23.4–25.3) |
| S2 `.app` size (MB) | 5.6 | 5.8 | 47.2 | 43.6 |
| Launches / journeys | 20 / 6 | 20 / 6 | 20 / 5 | 20 / 6 |

F1–F3 are in `results/2026-11-14-hitches/`. E1 was not measured (the device was charging).

## Whisker

- `Cargo.toml` moves to `whisker` 0.18 and `whisker-cng` 0.18.1, and `cargo update` takes the packages to their latest 0.14 releases (router 0.14.6, the others 0.14.7). The app's own native module (`shop-native`) moves to `whisker`/`whisker-plugin` 0.18 and its SwiftPM pin from 0.1.20 to 0.1.22, which the 0.14.7 packages require. No app source changed.
- N1 is unchanged: journey 1 fetches the images, and journeys 2–3 are served from Whisker's image disk cache, as described in `results/2026-11-11/README.md`.

## NativeScript

### Version

`@nativescript/core` 9.1.4 and `@nativescript/webpack` 5.0.41, the latest releases. The runtime (`@nativescript/ios` 9.1.1) and the Matter metadata exclusion are from PR #1, which merged after 2026-11-11, so this is their first device measurement; the exclusion accounts for most of the S2 drop.

### The `ListView` workaround

The AI's build crashed in the iOS `ListView` and worked around it by replacing `ListView._removeContainer` with a no-op (`app/lib/paged-list.ts`). XCUITest, which drives the journey, is an accessibility client, and while it is attached `UITableView` does not reuse cells. With `_removeContainer` disabled, NativeScript kept the item view of every cell UIKit dropped, which is most of the 1.7 GB peak measured on 2026-11-11 (PR #2).

The fix PR #2 proposed for core (NativeScript/NativeScript#11637) was closed without merging and is not in 9.1.4. This benchmark measures released framework versions only, so core is not patched. Instead the app's workaround was changed by hand on 2026-11-14:

- Core's `_removeContainer` tears down a cell's item view but leaves it on the cell, and reusing the cell revives the torn-down view, which throws inside `cellForRowAtIndexPath`. The app now calls the original `_removeContainer` and then clears the cell's reference, so a reused cell builds a fresh item view.
- Verification on the iOS 27.2 simulator, Release builds, with the benchmark's own `testJourney`: without any workaround the app crashed 4 / 4 (`-[UITableView _createPreparedCellForGlobalRow:…]` assertion); with this change it passed 3 / 3. All 6 device journeys in this run passed.

This is a change to the AI's app code, like the hand fix in `results/xcode27/`. The 2026-11-11 numbers stay as the measurement of the AI's build.

### Reading the numbers

- M2 falls from 1.7 GB to 168 MB and M3 from 382 to 146 MB. The app still has no image cache (`results/2026-11-11/README.md`), so N1 and C1 barely change.
- C2 peak rises from 71 % to 88 %. A sort change or a new page now builds new item views for the reloaded cells instead of keeping the old ones, which is the likely cause; it was not profiled.

## How this run differs from `results/2026-11-11/`

- Two rounds with rotated order (round 1 Whisker first, round 2 NativeScript first), no reboot between apps, device charging, each app reinstalled per round and settled 180 s, 10 launches after one discarded warm-up and 3 journeys under Activity Monitor + os_log. The `bench.py` changes from `results/2026-11-13/` apply.
- A first driver run was stopped during Whisker's settle period, before any trial was recorded, so NativeScript could be rebuilt with the PR #1 changes; its output was discarded. `measure.log` holds the run that produced these numbers.
- In round 2, Whisker's launch 7 failed twice when the xctrace launch recording hung, as on 2026-11-13. Terminating the app process left on the device let the third attempt pass.

## Files

| Path | Contents |
|---|---|
| `summary.json` | The table above for this run, pooled over both rounds |
| `round-<r>/<app>/metrics.json` | Per-trial values and the per-run summary |
| `round-<r>/<app>/launch-<n>.log`, `activity-<n>/` | xctrace, runner, and replay logs per trial (traces are kept locally) |
| `measure.log`, `replay.log` | The driver run, and every request the replay server answered |
| `x-images/` | Charts made from this run, `results/2026-11-14-hitches/`, and the UIKit and SwiftUI values in `results/2026-11-13/`, with the HTML they are rendered from |

The device identifier and name are replaced with `<device-udid>` and `<device-name>` in the logs.
