# Results: 2026-11-11

Six builds of the same shop app, one per framework, measured on a physical iPhone 12 (iOS 27.2) with the protocol in `measurement/README.md`. The apps are the unmodified AI outputs in `apps/`.

## Summary

Median, with the interquartile range in parentheses, pooled over both rounds.

| Metric | NSH | Exact | React Native | Whisker | Flutter | NativeScript |
|---|---|---|---|---|---|---|
| L1 launch → first frame (ms) | 94 (93–97) | 211 (211–214) | 132 (131–135) | 154 (151–155) | 142 (140–156) | 226 (225–229) |
| L2 launch → content (ms) | 164 (161–170) | 301 (299–301) | 211 (203–224) | 166 (165–211) | 211 (202–252) | 373 (333–375) |
| M1 memory after launch (MB) | 20 (19–20) | 20 (20–20) | 46 (45–47) | 93 (92–94) | 123 (123–125) | 85 (84–87) |
| M2 peak memory (MB) | 45 (43–46) | 52 (51–53) | 115 (114–118) | 375 (371–383) | 307 (306–308) | 1706 (1694–1716) |
| M3 memory after journey (MB) | 44 (42–44) | 37 (36–38) | 72 (71–73) | 346 (343–348) | 277 (275–279) | 382 (354–386) |
| C1 CPU time over journey (s) | 56.1 (55.5–56.4) | 78.3 (77.9–78.4) | 86.2 (85.2–87.6) | 85.3 (84.8–85.6) | 85.5 (85.0–86.3) | 105.3 (103.5–105.4) |
| C2 avg CPU while scrolling (%) | 10.9 (10.7–11.0) | 16.7 (16.5–16.8) | 19.2 (18.8–19.5) | 16.2 (15.9–16.5) | 32.1 (31.8–32.6) | 19.9 (19.8–20.2) |
| C2 peak CPU while scrolling (%) | 36 (34–39) | 50 (47–52) | 46 (46–49) | 41 (40–47) | 52 (50–55) | 71 (65–75) |
| N1 requests per journey | 233 (211–233) | 256 (252–257) | 451 (446–456) | 41 (41–206) ¹ | 279 (279–280) | 716 (689–732) |
| N1 MB per journey | 7.1 (6.2–7.1) | 8.7 (8.5–8.7) | 15.9 (15.7–16.2) | 0.3 (0.3–5.7) ¹ | 8.4 (8.4–8.4) | 24.3 (24.0–24.7) |
| S2 `.app` size (MB) | 27.6 | 34.7 | 23.8 | 5.6 | 16.5 | 47.2 |
| Launches / journeys | 20 / 6 | 20 / 6 | 20 / 6 | 20 / 6 | 20 / 6 | 20 / 5 ² |

¹ See "Image caching" below: Whisker's journeys after the first fetch no images.
² One NativeScript journey recorded no runner phase marks (the os_log stream dropped the whole trial) and is excluded.

Rounds 1 and 2 agree within a few percent for every app and metric except Whisker's L2 (see "Run-to-run variance"), so the planned third round was not run. Per-round values are in `round-*/<app>/metrics.json`.

Not measured in this run: F1–F3 (an earlier Animation Hitches trial produced traces without kernel-trace data, so hitches were left out until recording is fixed) and E1 (the device was charging, and the system power level reads 0 %/hour while charging).

## How this run differs from `measurement/README.md`

- Two rounds instead of three. App order rotated between them (round 1 React Native first, round 2 Flutter first).
- The device was not rebooted before each app, and it was charging throughout.
- Each app was reinstalled at the start of every round, settled 180 s, then measured: 10 launches (after one discarded warm-up launch) and 3 journeys under Activity Monitor + os_log.
- Journeys that failed in the UI test were retried (`<kind>-<n>-failed-<attempt>` directories, excluded from the numbers). Round 2 React Native journeys 2–3 were re-recorded after a reinstall because the run was interrupted (`activity-2-failed-killed`).

## Reading the numbers

### L1 is when iOS sees the first frame, not when the skeleton is visible

L1 is the end of the system's "Initial Frame Rendering" launch phase, recorded by iOS rather than reported by the app. It ends at the app's first committed frame, whatever that frame shows. Flutter and Exact first commit a blank view and draw their own skeleton afterwards, so their L1 is earlier than what a user sees. In a single 30 fps screen recording of a Home Screen tap per app (not part of this run's data), the skeleton appeared this long after the launch animation started: Whisker ≈ 200–230 ms, NSH and React Native ≈ 270 ms, NativeScript ≈ 330–370 ms, Flutter ≈ 400–450 ms, Exact ≈ 700 ms.

L2 is each app's own `SHOPBENCH home_ready` log line. Every app emits it right after the Home response is applied, without waiting for images; React Native and Whisker emit it about one frame before the content is painted.

Launches are 5 s apart, so binaries are in the OS file cache: these are process-cold launches, not launches after a reboot.

### Image caching shapes N1, and partly M2

The replay server serves images with `Cache-Control: public, max-age=60`, as the real CDN does. The frameworks handle it differently:

| App | Image cache | Effect |
|---|---|---|
| NSH | Memory + disk, honors `max-age`, downsamples to view size | Re-fetches only after expiry |
| Exact | Disk HTTP cache + bounded decoded-image pool, downsamples | Few re-fetches |
| React Native | 20 MB memory cache + URLCache (honors `max-age`); `FlatList` unmounts off-window cells | Cells scrolled back after 60 s re-fetch (≈ 230 duplicate image requests) |
| Flutter | Memory only (100 MB), no disk cache | Re-fetches once the memory cache overflows |
| Whisker | Kingfisher in the framework: memory + 7-day disk cache, ignores `max-age`, no downsampling | Journey 1: 206 requests; journeys 2–3: 41 (API only). CPU and memory are the same in all three journeys, so only N1 is affected |
| NativeScript | None in the app (core `Image` with a URL); iOS's default small URL cache | ≈ 500 duplicate image requests per journey |

### Fairness review of the app code

Each app was read against `prompt/PROMPT.md`. All six send the operations verbatim, use page size 24, load the next page within one screen of the end, apply the specified `width` values, virtualize the Collection grid and Search results, and emit `home_ready` after the Home data arrives. No app skips required UI or loads less data than the spec. Differences that move the numbers:

- **NativeScript**: no image cache in the app. Every recycled cell and revisited screen downloads and decodes its image again, which accounts for most of its 716 requests and most of its 1.7 GB peak (M3 falls back to ≈ 380 MB, so the peak is uncollected garbage). Core NativeScript's `ImageCache` would avoid this. The numbers show this implementation, not the framework's floor.
- **Exact**: caches Product responses for the session. The journey opens two distinct products repeatedly, so Exact sends up to ≈ 10 fewer `Product` requests. Its L2 includes an extra hop because it reads the endpoint after the first frame.
- **Whisker**: on back from a recommended product, the revealed Product screen re-requests its data twice (framework router behavior), and the product back button does not scroll with the page as the design specifies, which saves the runner a few flings. No downsampling and eager carousels contribute to its M2.
- **React Native**: no push/pop transition animation (no navigation library), a small CPU saving.
- **Flutter**: builds the Search and Cart tabs at launch inside an `IndexedStack`, a small launch cost.
- **NSH**: cancels image downloads for cells recycled before they load, a standard optimization.

### Run-to-run variance

Whisker's L2 median was 198 ms in round 1 and 165 ms in round 2 with L1 unchanged. The first-frame-to-content gap falls into two clusters (≈ 12 ms and ≈ 58 ms), consistent with LAN round-trip jitter on the Home request; NativeScript shows the same two clusters (≈ 80 / 148 ms).

## Files

| Path | Contents |
|---|---|
| `summary.json` | The table above, from `tools/extract.py` over both rounds |
| `round-<r>/<app>/metrics.json` | Per-trial values and the per-run summary |
| `round-<r>/<app>/launch-<n>.log`, `activity-<n>/` | xctrace, runner, and replay logs per trial (traces are kept locally) |
| `measure.log`, `replay.log` | Driver log and every request the replay server answered |

The device identifier is replaced with `<device-udid>` in the logs.
