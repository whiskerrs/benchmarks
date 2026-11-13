# Results: 2026-11-13, hitches

F1–F3 for UIKit, SwiftUI, and NativePHP on the same iPhone 12 (iOS 27.2, 60 Hz), complementing `results/2026-11-13/` and measured as in `results/2026-11-12-hitches/`.

## Summary

Median of three runs per app, with each run in brackets.

| Metric | UIKit | SwiftUI | NativePHP |
|---|---|---|---|
| F1 hitch time while scrolling (ms/s) | 0.1 [0.1, 0.1, 0.0] | 0.0 [0.0, 0.0, 0.0] | 0.1 [0.1, 0.6, 0.1] |
| F2 hitches while scrolling | 1 [1, 1, 0] | 0 [0, 0, 0] | 1 [1, 5, 1] |
| F3 hitch time on Product push/pop (ms/s) | 4.5 [4.4, 5.4, 4.5] | 1.8 [2.7, 1.8, 1.8] | 7.9 [4.0, 18.9, 7.9] |

Apple's guidance for the hitch time ratio: under 5 ms/s good, 5–10 warning, over 10 critical.

## Method

- The same `testHitches` journey and Hitches + os_log recording as `results/2026-11-12-hitches/README.md`.
- One round, UIKit first. Each app was installed alone, settled 180 s (60 s on 2026-11-12), run three times, and uninstalled.
- UIKit was measured twice. The first three runs were taken while the Mac was building other projects and were discarded; the numbers here are from the second pass (`measure.log`, driver run 2).
- Journeys that recorded no usable trace were retried and are kept as `hitches-<n>-failed-<attempt>`.

## Reading the numbers

- All three scroll without meaningful hitches. Their hitches come from Product push/pop.
- NativePHP's second run is an outlier (F3 18.9 ms/s, 22 hitches in the trace against 9 and 11). The cause was not investigated.
- Scroll phases take about 35 s on Home and 104–111 s on the collection for all three, close to the native-view apps measured on 2026-11-12.

## Files

| Path | Contents |
|---|---|
| `summary.json` | Median and quartiles of F1–F3 per app |
| `round-1/<app>/metrics.json` | Per-run values and phase durations |
| `round-1/<app>/hitches-<n>/` | Runner, xctrace, and replay logs per run (traces are kept locally) |
| `measure.log`, `replay.log` | The two driver runs in order, and every request the replay server answered |

The device identifier and name are replaced with `<device-udid>` and `<device-name>` in the logs.
