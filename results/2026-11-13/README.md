# Results: 2026-11-13

Three more builds of the same shop app, UIKit, SwiftUI, and NativePHP, measured on the same iPhone 12 (iOS 27.2) with the same protocol as `results/2026-11-11/`. A fourth, DartNative, was built but not measured.

These apps were measured two days after the first six, with a changed `bench.py` (see "How this run differs"). Compare them with `results/2026-11-11/` with that in mind.

## Summary

Median, with the interquartile range in parentheses, pooled over both rounds.

| Metric | UIKit | SwiftUI | NativePHP |
|---|---|---|---|
| L1 launch → first frame (ms) | 141 (140–143) | 156 (155–158) | 112 (109–130) |
| L2 launch → content (ms) | 205 (202–244) | 218 (215–240) | 410 (367–605) |
| M1 memory after launch (MB) | 49 (48–50) | 64 (63–65) | 235 (234–235) |
| M2 peak memory (MB) | 154 (153–155) | 131 (129–131) | 305 (303–307) |
| M3 memory after journey (MB) | 146 (146–147) | 108 (107–109) | 305 (303–307) |
| C1 CPU time over journey (s) | 83.0 (82.7–84.0) | 103.4 (101.9–103.9) | 94.2 (92.9–95.5) |
| C2 avg CPU while scrolling (%) | 17.6 (17.5–17.7) | 23.4 (23.4–23.5) | 20.3 (20.2–20.3) |
| C2 peak CPU while scrolling (%) | 63 (61–67) | 53 (52–56) | 76 (68–81) |
| N1 requests per journey | 304 (303–304) | 406 (399–408) | 476 (444–485) |
| N1 MB per journey | 9.9 (9.9–9.9) | 13.8 (13.5–13.9) | 16.5 (15.9–17.4) |
| S2 `.app` size (MB) | 1.0 | 2.1 | 49.5 |
| Launches / journeys | 20 / 6 | 20 / 6 | 20 / 6 |

F1–F3 are in `results/2026-11-13-hitches/`. E1 was not measured (the device was charging).

## The apps

Each app was built by Claude Code from one message, as in `prompt/README.md`, with model `claude-opus-5-5`, effort `high`, and Claude Code 2.1.316. Records and transcripts are in `results/ai-runs/<app>/`.

| App | Prompt variant | Wall time (min) | Turns | Cost (USD) | Outcome |
|---|---|---|---|---|---|
| UIKit | `ios-only` | 20.0, then 19.1 | 55, then 13 | 4.00, then 6.20 in total | Measured after one human message |
| SwiftUI | `ios-only` | 22.8 | 63 | 3.37 | Measured as built |
| NativePHP | `webview` | 58.4 | 266 | 24.25 | Measured as built |
| DartNative | none | 24.9 | 153 | 11.40 | Built, never run |

- **Prompt variants** (`prompt/frameworks.md`): `ios-only` removes every Android requirement, so the UIKit and SwiftUI runs did less work than the others and their time and cost are not comparable. `webview` lifts the WebView ban for NativePHP.
- **UIKit is not an unmodified output.** The first build crashed on the device every time a collection was opened (`NSInternalInconsistencyException` from `performBatchUpdates`). The session was resumed with one message describing the crash, recorded verbatim in `results/ai-runs/uikit/run.json`, and `apps/uikit/` is the fixed app.
- **NativePHP** used NativePHP 4.7.0, which renders with SwiftUI on iOS, so the app has no WebView and the `webview` variant changed nothing in practice.
- **DartNative** needs a paid license key to run. The AI's build completes, but without a key the app was never run, so it was neither verified by hand nor measured. `apps/dartnative/` is that unverified output.

## How this run differs from `results/2026-11-11/`

- A different day, and the Mac was shared with other work for part of it.
- `tools/bench.py` changed: a journey now aborts as soon as xctrace stops recording, and a trial is tried up to six times instead of three.
- The driver was restarted nine times (`measure.log` holds all ten runs in order). Causes: another process driving the same iPhone, the iPhone falling back to Wi-Fi so that xctrace dropped the connection, the Mac sleeping, a full disk, a pause, and in round 2 a UIKit launch recording that hung three times for a reason that was not found. Each restart skipped the apps already measured and redid the interrupted app from its install.
- As on 2026-11-11: two rounds with rotated order (round 1 UIKit first, round 2 SwiftUI first), no reboot between apps, device charging, each app reinstalled per round and settled 180 s, 10 launches after one discarded warm-up and 3 journeys under Activity Monitor + os_log. Failed journeys are kept as `<kind>-<n>-failed-<attempt>` and excluded.

## Reading the numbers

- The app code was not reviewed against the prompt as it was for the first six, so differences in N1 and memory are reported without an explanation.
- **L2 − L1.** UIKit and SwiftUI show content about 60 ms after the first frame in most launches and 100–160 ms after in a few, the same two clusters seen on 2026-11-11 and attributed there to LAN jitter on the Home request. NativePHP's gap is 230–950 ms.
- **NativePHP launches.** Two launches in round 1 were slow (L1 641 and 1381 ms, L2 1420 and 2331 ms). Round 2 had none (L1 108–134 ms). The cause was not investigated; the medians are barely affected.
- **Round-to-round.** Rounds agree within a few percent except NativePHP's L2 (438 → 370 ms), NativePHP's peak CPU (70 → 80 %), and UIKit's L2 (205 → 222 ms, with L1 unchanged).

## Files

| Path | Contents |
|---|---|
| `summary.json` | The table above, pooled over both rounds |
| `round-<r>/<app>/metrics.json` | Per-trial values and the per-run summary |
| `round-<r>/<app>/launch-<n>.log`, `activity-<n>/` | xctrace, runner, and replay logs per trial (traces are kept locally) |
| `measure.log`, `replay.log` | The ten driver runs in order, and every request the replay server answered |

The device identifier and name are replaced with `<device-udid>` and `<device-name>` in the logs.
