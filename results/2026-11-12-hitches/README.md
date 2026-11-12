# Results: 2026-11-12, hitches

F1–F3 for the six apps on the same iPhone 12 (iOS 27.2, 60 Hz), complementing `results/2026-11-11/`.

## Summary

Median of three runs per app, with each run in brackets.

| Metric | NSH | Exact | React Native | Whisker | Flutter | NativeScript |
|---|---|---|---|---|---|---|
| F1 hitch time while scrolling (ms/s) | 0.0 [0.0, 0.0, 0.0] | 0.0 [0.0, 0.2, 0.0] | 0.1 [0.1, 1.3, 0.1] | 4.2 [2.5, 4.2, 6.4] | 1.8 [1.8, 2.4, 1.8] | 6.0 [5.6, 6.6, 6.0] |
| F2 hitches while scrolling | 0 [0, 0, 0] | 0 [0, 2, 0] | 1 [1, 11, 1] | 39 [23, 39, 60] | 10 [10, 13, 10] | 18 [16, 21, 18] |
| F3 hitch time on Product push/pop (ms/s) | 0.0 [0.0, 0.0, 0.0] | 0.0 [0.0, 1.7, 0.0] | 7.5 [6.7, 16.0, 7.5] | 40.4 [35.7, 41.4, 40.4] | 0.0 [0.0, 0.0, 0.0] | 39.9 [47.4, 32.5, 39.9] |

Apple's guidance for the hitch time ratio: under 5 ms/s good, 5–10 warning, over 10 critical.

## Method

- `bench.py journey --instrument hitches` runs the runner's `testHitches`: launch, 8+8 flings on Home, 20+20 flings on the first collection, then three Product push/pops. Each run is recorded with the Hitches and os_log instruments for all processes; the os_log phase marks cut the trace into phases.
- A run of the full journey under the Animation Hitches template produced traces with no kernel-trace data, and the template's time profiler made a two-minute trace take about 15 minutes to save. The Hitches instrument alone saves in under a minute and reports the same hitches.
- The app's hitches are the rows charged to a process other than SpringBoard; rows without a process are system-wide.
- One round, React Native first. Each app was installed alone, settled 60 s, run three times 60 s apart, and uninstalled.

## Reading the numbers

- NSH and Exact recorded no hitch while scrolling or navigating in any run. The traces do contain SpringBoard's hitches and, for NSH, one hitch at launch, so recording worked.
- Flutter drops single frames while scrolling (every hitch is one 16.7 ms frame) and none on push/pop.
- React Native scrolls cleanly; its hitches come from Product push/pop.
- Whisker and NativeScript are in the critical range on Product push/pop. Most of Whisker's hitches are attributed to GPU work. Both decode images without downsampling and build all ten carousel images at 1080 px when a Product screen opens (see the code review in `results/2026-11-11/README.md`). Whisker's F1 rose across its three runs, the later two served from its image disk cache.
- Scroll phases take longer on the apps built from native views (NSH, Whisker: about 36 s on Home and 112 s on the collection) than on Flutter (27 s and 64 s) for the same flings, because the runner's element queries are slower there. The ratios are per second, so this does not bias F1 or F3.

## Files

| Path | Contents |
|---|---|
| `summary.json` | Median and quartiles of F1–F3 per app |
| `round-1/<app>/metrics.json` | Per-run values and phase durations |
| `round-1/<app>/hitches-<n>/` | Runner, xctrace, and replay logs per run (traces are kept locally) |
| `measure.log`, `replay.log` | Driver log and every request the replay server answered |
