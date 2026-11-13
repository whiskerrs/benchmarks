# Tools

- `replay/replay.py`: record-and-replay server for the Storefront API and images.
- `runner/`: XCUITest runner that drives the journey scenario on the device.
- `bench.py`: host-side driver that installs apps, records Instruments traces, and runs the runner.

## Replay data

```sh
python3 tools/replay/replay.py crawl           # pre-record what the journey reaches (slow: fetches every image)
python3 tools/replay/replay.py record          # serve; fetch and store anything missing
python3 tools/replay/replay.py serve           # serve recordings only; misses return 404
```

Recordings are written to `tools/replay/data/`. `responses/` and `images.json` are committed so the dataset stays fixed even if mock.shop changes; `images/` is not, and `crawl` re-fetches it from the URLs in `images.json`. Before measuring, run each app's journey once against `record`, so requests the crawl did not anticipate are captured, then measure against `serve`.

`GET /_stats` returns request and byte counts and misses since the last `POST /_reset`.

## Runner

```sh
cd tools/runner
xcodegen generate
DEVELOPMENT_TEAM=XXXXXXXXXX xcodebuild build-for-testing -project ShopBenchRunner.xcodeproj -scheme ShopBenchRunner \
  -destination 'generic/platform=iOS' -derivedDataPath build/device -allowProvisioningUpdates
```

## Measuring

`measure.py` runs the whole protocol: it starts the replay server (`serve`), then for each app installs it alone, settles, records launches and journeys, uninstalls it, and extracts `metrics.json`. An app whose `metrics.json` already exists in the output is skipped, so a failed run resumes by running the same command again.

```sh
UDID=<device identifier from xcrun devicectl list devices>
HOST=<the Mac's LAN IP, reachable from the iPhone>
python3 tools/measure.py --udid $UDID --host $HOST --rounds 2 --instruments activity --out results/<date>
python3 tools/measure.py --udid $UDID --host $HOST --rounds 1 --launch-runs 0 --instruments hitches --out results/<date>-hitches
python3 tools/extract.py --summary results/<date>
```

The first command produced `results/2026-11-11/`, the second `results/2026-11-12-hitches/`. `--apps whisker,nsh` limits the run to some apps.

Builds are read from `~/shopbench-runs/<app>/`, where each app was built with its `BUILD.md` (paths in `APPS` in `measure.py`); `--app-path whisker=<path>.app` measures another build instead. The runner must be built first (see Runner).

`bench.py` measures one app step by step (`size`, `prepare`, `launch`, `journey`), and `extract.py <dir>` turns its traces into `metrics.json`; `measure.py` calls both.

## Re-measuring Whisker after a version bump

Device conditions change from day to day, so measure the current and the new Whisker build in the same session rather than comparing against an old result.

1. Release Whisker: the crates on crates.io and the matching iOS SwiftPM tag. The app's iOS module resolves the SwiftPM package from GitHub, and patching only some crates to a local checkout splits `whisker-runtime` in two, so a local checkout cannot stand in for a release.
2. Build the current version once and keep the `.app`:
   ```sh
   cd ~/shopbench-runs/whisker   # a copy of apps/whisker; build as in its BUILD.md
   mkdir -p ~/shopbench-builds
   cp -R build/device/Build/Products/Release-iphoneos/Everbloom.app ~/shopbench-builds/whisker-0.17.0.app
   ```
3. Bump the versions in the same copy, keeping all of them in step:
   - `Cargo.toml`: `whisker`, `whisker-cng`, and the `whisker-*` packages; then `cargo update`.
   - `shop-native/Package.swift`: the `exact:` pin of the Whisker SwiftPM package, to the version the new packages expect.
   - `whisker-cli` (`cargo install whisker-cli --version <v> --locked`).
4. Regenerate and rebuild (`cargo run --bin whisker-config --features whisker-config -- ios`, then the `xcodebuild` command in `BUILD.md`), and copy the `.app` to `~/shopbench-builds/whisker-<new>.app`.
5. Measure both builds, alternating the order between rounds:
   ```sh
   NEW=<new version>
   run() {  # run <round> <version>
     app=whisker=$HOME/shopbench-builds/whisker-$2.app
     python3 tools/measure.py --udid $UDID --host $HOST --apps whisker --first-round $1 --rounds $1 \
       --instruments activity --app-path $app --out results/<date>-whisker-$2
     python3 tools/measure.py --udid $UDID --host $HOST --apps whisker --first-round $1 --rounds $1 \
       --launch-runs 0 --instruments hitches --app-path $app --out results/<date>-whisker-$2-hitches
   }
   run 1 0.17.0; run 1 $NEW; run 2 $NEW; run 2 0.17.0
   ```
6. Compare `extract.py --summary` of the two output trees. Copy the version changes back into `apps/whisker/` and record them in its `BUILD.md`.

## Validated

- iOS Simulator, React Native (Release), 2026-11-10: the runner completes the whole journey (441 s), first against `record`, then against `serve` with zero misses.
- iPhone 12, iOS 27.2, all six apps, 2026-11-11 and 2026-11-12: `measure.py` as above.
- iPhone 12, iOS 27.2, UIKit, SwiftUI, and NativePHP, 2026-11-13: `measure.py` as above, restarted several times (`results/2026-11-13/README.md`).
