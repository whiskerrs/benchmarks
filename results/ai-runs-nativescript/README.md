# NativeScript AI runs

## API time in `run.json`

A headless session emits one `result` event each time it ends a turn, for example again after a background task finishes. `total_cost_usd` and `duration_api_ms` in those events are running totals for the session. `tools/ai_run.py` added `duration_api_ms` up across the events, so runs with more than one `result` reported their API time several times over. It now takes the last value, as it already did for cost. The corrected values are written into the two affected `run.json` files; `results/ai-runs-nativescript.log` is the original run's output and still shows the old value.

| Run | `result` events | `duration_api_ms` before | after |
|---|---|---|---|
| nativescript | 3 | 7,166,625 (119 min) | 2,392,530 (40 min) |
| react-native | 2 | 1,612,644 (27 min) | 814,574 (14 min) |

The chart and D1 use wall time and the cost uses the final running total, so neither changes.

## A second NativeScript run

`ai-runs/nativescript-run-2/` is a second run with the same prompt, model and `ai_run.py` command (`--run-name nativescript-run-2`), on another Mac, with `@nativescript/ios` 9.1.1 in place of 9.1.0. `--run-name` keeps a repeat run's workspace and results next to the first one instead of overwriting them.

| | nativescript | nativescript-run-2 |
|---|---|---|
| Started (UTC) | 2026-11-10 08:40 | 2026-11-12 04:37 |
| Claude Code | 2.1.316 | 2.1.322 |
| Cost (USD) | 20.72 | 16.41 |
| Turns | 283 | 227 |
| Wall time (min) | 107.3 ¹ | 100.5 |
| API time (min) | 39.9 | 30.0 |
| Human messages | 0 | 0 |

¹ `wall_seconds` comes from `time.monotonic()`, which stops while the Mac sleeps. The run's UTC timestamps span 120.2 min.

Differences in the second run's environment: Xcode 27.1, an iOS 26.5 simulator, and Maestro and idb installed (the agent used Maestro to drive the simulator).

### The ListView crash in both runs

Both runs hit the same crash in NativeScript's iOS `ListView`: after a sort change or the next page, `-[DictionaryAdapter CGColor]` (run 1) or `-[DictionaryAdapter _resolvedMaterialWithTraitCollection:]` (run 2) was sent to an unrecognized selector while a recycled cell's item view was rebuilt, and UIKit then aborted with a nil cell. Neither run found the cause; both worked around it by overriding the private `ListView._removeContainer`. The cause is in `@nativescript/core` and is fixed upstream in NativeScript/NativeScript#11637.

| | nativescript | nativescript-run-2 |
|---|---|---|
| Crash first seen → workaround in place (min) | 35.2 → 87.2 | 16.7 → 73.5 |
| Share of assistant messages in that window | 18 % | 37 % |
| Share of input-side tokens in that window | 19 % | 39 % |

Run 1 spent most of that window waiting on long simulator stress runs; run 2 also did unrelated work in it (build scripts, the Android build, docs), so these shares are upper bounds for the crash alone.

The two runs differ by 21 % in cost and 20 % in turns with the same prompt and the same framework bug. With one run per framework, D1–D3 differences of that size are within run-to-run variation; three or more runs per framework would separate the framework from the run.
