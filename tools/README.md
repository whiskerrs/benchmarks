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

## Measuring one app

```sh
API=http://<mac LAN IP>:8787/api
UDID=$(xcrun devicectl list devices | ...)   # the test iPhone
python3 tools/bench.py size    --app <device .app> --thinning-report <App Thinning Size Report.txt> --out results/<date>/<app>
python3 tools/bench.py launch  --app <device .app> --bundle-id dev.whiskerrs.shopbench.<suffix> --udid $UDID --api $API --out results/<date>/<app>
python3 tools/bench.py journey --bundle-id dev.whiskerrs.shopbench.<suffix> --udid $UDID --api $API --instrument activity --out results/<date>/<app>
python3 tools/bench.py journey ... --instrument hitches
python3 tools/bench.py journey ... --instrument power
```

## Not yet done

- Extracting metrics from the traces (`xctrace export`) needs the table schemas from a real device trace; written once the first device run exists.
- `bench.py launch`: on the simulator, xctrace accepts `App Launch` + `--instrument os_log` + `--launch -- <bundle id>` but never finishes the recording (also with the `.app` path). Confirm on the device.
- `bench.py` itself has not run yet.

## Validated

On the iOS Simulator with the React Native app (Release build), 2026-11-10: the runner completes the whole journey (441 s), first against `record`, then against `serve` with zero misses (629 requests, 24.4 MB).
