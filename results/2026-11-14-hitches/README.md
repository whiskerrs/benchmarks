# Results: 2026-11-14, hitches

F1–F3 for Whisker 0.18.1 and NativeScript (core 9.1.4 with the hand-changed `ListView` workaround) on the same iPhone 12 (iOS 27.2, 60 Hz), complementing `results/2026-11-14/`. The builds are the ones measured there.

## Summary

Median of three runs per app, with each run in brackets. The 2026-11-12 values are from `results/2026-11-12-hitches/`.

| Metric | Whisker 0.17.0 (11-12) | Whisker 0.18.1 | NativeScript (11-12) | NativeScript (this run) |
|---|---|---|---|---|
| F1 hitch time while scrolling (ms/s) | 4.2 [2.5, 4.2, 6.4] | 0.2 [0.2, 0.3, 0.2] | 6.0 [5.6, 6.6, 6.0] | 0.7 [0.7, 1.8, 0.6] |
| F2 hitches while scrolling | 39 [23, 39, 60] | 2 [2, 3, 2] | 18 [16, 21, 18] | 6 [6, 16, 5] |
| F3 hitch time on Product push/pop (ms/s) | 40.4 [35.7, 41.4, 40.4] | 6.8 [6.8, 7.0, 5.9] | 39.9 [47.4, 32.5, 39.9] | 8.0 [8.0, 15.0, 7.0] |

Apple's guidance for the hitch time ratio: under 5 ms/s good, 5–10 warning, over 10 critical.

## Method

Same as `results/2026-11-12-hitches/` (`testHitches` under the Hitches and os_log instruments, three runs per app), except:

- One round, Whisker first, run straight after `results/2026-11-14/` with the same builds. Each app was reinstalled and settled 180 s instead of 60 s.
- Only these two apps were measured, so the 2026-11-12 values for the other four apps are not re-measured.

## Reading the numbers

- Whisker moves out of the critical range on Product push/pop and scrolls with a few single hitches. Its second and third runs are served from its image disk cache (9 requests against 88 for the first) and show the same values.
- NativeScript's F3 falls from 39.9 to 8.0 ms/s. The 2026-11-12 build kept every dropped cell's item view (`results/2026-11-14/README.md`), so the change cannot be split between core 9.1.4 and the hand-changed workaround. Its second run is the outlier in all three metrics.
- Both apps stay in the warning range on push/pop.

## Files

| Path | Contents |
|---|---|
| `summary.json` | Median and quartiles of F1–F3 per app |
| `round-1/<app>/metrics.json` | Per-run values and phase durations |
| `round-1/<app>/hitches-<n>/` | Runner, xctrace, and replay logs per run (traces are kept locally) |
| `measure.log`, `replay.log` | Driver log and every request the replay server answered |

The device identifier and name are replaced with `<device-udid>` and `<device-name>` in the logs.
