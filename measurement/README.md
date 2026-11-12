# Measurement methodology

What is measured, how, and under which conditions. Every app is the release build produced from `prompt/PROMPT.md`, measured on one physical iPhone.

## Metrics

| # | Metric | Unit | Source |
|---|---|---|---|
| D1 | AI build time | min | Run protocol (`prompt/README.md`): message sent → final turn ends |
| D2 | AI tokens and cost | tokens, USD | Session usage |
| D3 | Turns, tool calls, build invocations | count | Transcript |
| D4 | Human interventions | count | Run log (target: 0) |
| D5 | Spec conformance | passed / total | Done checklist in `PROMPT.md`, verified by hand on the device |
| D6 | App source size and added dependencies | lines, count | `cloc` over hand-written source; `NOTES.md` |
| S1 | Install size (thinned, for the test device) | MB | App Thinning Size Report from an ad-hoc export: uncompressed and compressed for the test device's variant |
| S2 | `.app` bundle size | MB | Release device `.app` directory bytes |
| L1 | Cold launch to first frame | ms | Instruments **App Launch** |
| L2 | Cold launch to content | ms | `SHOPBENCH home_ready` os_log timestamp − process start, from the same trace with the **os_log** instrument |
| M1 | Memory after launch | MB | Physical footprint 5 s after `home_ready` |
| M2 | Peak memory over the journey | MB | Maximum physical footprint during the journey scenario |
| M3 | Memory after the journey | MB | Physical footprint after returning to Home and idling 5 s (retention / leaks) |
| F1 | Hitch time ratio while scrolling | ms/s | Instruments **Hitches** instrument, scroll phases only |
| F2 | Hitch count while scrolling | count | Same trace |
| F3 | Hitch time ratio during navigation | ms/s | Same trace, push/pop phases |
| C1 | CPU time over the journey | s | Instruments **Activity Monitor**, process CPU time delta |
| C2 | Average / peak CPU while scrolling | % | Same trace, scroll phases |
| E1 | Energy over the journey | Power Profiler impact | Instruments **Power Profiler** (supplementary) |
| N1 | Bytes and requests served | bytes, count | Replay server log (validation: apps must request the same data) |

M1–M3 use the physical footprint (`phys_footprint`), the figure iOS uses for memory limits. Which Activity Monitor column maps to it is confirmed during harness bring-up and recorded here.

## Device and environment

- One iPhone: an iPhone 12 (A14, 60 Hz display) on iOS 27.2, the iOS matching the Xcode 27.2 SDK every app is built with. Model, iOS build, and storage free space are recorded with every result.
- Wi-Fi on the same network as the Mac running the replay server; cellular off; Bluetooth off; Low Power Mode off; auto-brightness and True Tone off, brightness fixed at 50%; Do Not Disturb on; no other apps running.
- Connected to the Mac by cable for Instruments and XCUITest. Battery above 80%.
- Before each app: reboot the device, wait 3 minutes, check the thermal state is nominal (`ProcessInfo.thermalState` from the runner).
- Only one benchmark app is installed at a time.
- App order is rotated each round (round 1 A→F, round 2 B→F→A, …) so thermal drift and time of day are not tied to one framework.

## Replay server

All API and image traffic goes to the replay server (`tools/replay/`), never to mock.shop, during measurement.

- Responses are recorded once from mock.shop, then served from disk. `extensions` is removed.
- Requests are matched on `operationName` plus variables, with `null`-valued variables dropped. A request with no recording returns HTTP 404 and is logged; any miss invalidates the run.
- Image URLs in responses are rewritten to the replay server. Images are fetched once from the Shopify CDN as JPEG at each requested `width` and served with the same bytes regardless of the client's `Accept` header, so every framework downloads identical images. Image responses carry the CDN's `Cache-Control: public, max-age=60`, so HTTP caches behave as they would against the real CDN.
- Cart operations are emulated in memory from recorded variant data, so cart IDs and totals are deterministic.
- No artificial latency by default. The server records bytes and request counts per run (N1).

## Scenarios

Driven by an XCUITest runner (`tools/runner/`) that launches the app by bundle identifier with `SHOP_API_URL` set and finds elements by the identifiers required in `PROMPT.md`. Scrolling uses `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)` with fixed distances and velocities, so every app receives the same gestures.

### Launch (L1, L2)

1. Install the app, launch it once, terminate it (the first launch after install is discarded).
2. Ten times: terminate, wait 5 s, record a cold launch under App Launch + os_log until `home_ready` + 2 s.

### Journey (M, F, C, E)

One run takes about 7–8 minutes (React Native on the simulator: 441 s). XCUITest waits for the app to go idle before every gesture, so a fling starts once the previous one has settled, and phase durations differ between apps. Hitch metrics are per second of phase time, and CPU is reported per phase as well as for the whole journey. Each step waits for the named element before acting.

1. Launch, wait for `best-seller-0`, idle 5 s → sample M1.
2. **Home scroll** (`home-scroll`): fling up to the bottom, then back to the top.
3. **Collection scroll**: tap `collection-chip-0`, wait for `product-card-0`. 20 flings toward the end, then 20 back. Two cycles. A fling is a 400 pt drag at 3 000 pt/s, one every 0.6 s.
4. **Sort**: tap `sort-price-desc`, wait for `product-card-0`, one fling down and up.
5. **Product navigation**, five times: tap `product-card-<n>` (n = 0…4), swipe `product-carousel` left twice, scroll to the bottom, tap `recommendation-0`, then `back` twice.
6. **Search**: tap `tab-search`, type `jacket` into `search-input`, wait for `search-result-0`, fling to the end of the results (81) and back.
7. **Cart**: open `search-result-0`, `add-to-cart`; repeat for two more results; tap `qty-inc-0` twice and `qty-dec-1` until the line disappears.
8. Tap `tab-home`, idle 5 s → sample M3.

The journey is run three times under each of: Activity Monitor (M, C) and Power Profiler (E). Hitches (F) are recorded three times over a shorter journey (`testHitches`: launch, Home and Collection scrolling, three Product push/pops), with the Hitches instrument alone: a full journey under the Animation Hitches template loses its kernel-trace data. The app's hitches are those charged to a process other than SpringBoard. Separate traces keep one instrument's overhead out of another's numbers. The runner writes a timeline of phase boundaries so traces can be cut into phases.

## Repetitions and reporting

- Launch: 10 cold launches × 3 rounds. Journey: 3 runs × 3 instruments × 3 rounds.
- Report the median and the interquartile range. Raw traces, the runner timeline, replay logs, device info, and build metadata (toolchain versions, build mode, git revisions) are kept under `results/<date>/<app>/`.
- A run is invalid, and repeated, if the runner fails a step, the replay server logs a miss, or the device's thermal state is above nominal.
- An app that fails Done checklist items is still measured; the failures are reported next to its numbers.

## Limitations

- Results describe these AI-built apps, not the frameworks' best possible performance.
- One device and one OS version. The display runs at 60 Hz, so hitches are judged against a 16.7 ms frame budget and say nothing about 120 Hz rendering.
- Identical gestures do not give identical scroll distances: fling momentum follows each framework's own deceleration physics, so 20 flings may reach the end of a collection in one app and not in another. The replay server's per-run request count (N1) shows how many pages each app loaded and is reported next to M2 and F1.
- XCUITest uses CPU on the device. During flings the runner only sleeps, so the cost is the same for every app; element queries in navigation steps walk the app's accessibility tree, whose size differs between frameworks, so F3 and C1 include some framework-dependent runner cost.
