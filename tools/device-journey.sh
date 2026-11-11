#!/bin/bash
# Runs the journey once per app on the connected iPhone against the replay server and keeps the
# runner log, replay stats, and the XCTest screen recording under results/device-journey/<app>/.
#   tools/device-journey.sh <device udid> <mac LAN IP> <app>:<bundle id suffix>:<device .app> ...
set -u
cd "$(dirname "$0")/.."
DEV=$1 HOST=$2
shift 2
OUT=results/device-journey
XCTESTRUN=tools/runner/build/device/Build/Products/record.xctestrun
mkdir -p $OUT
python3 tools/replay/replay.py serve --port 8787 --log $OUT/replay.log > $OUT/replay.stdout 2>&1 &
REPLAY=$!
trap 'kill $REPLAY' EXIT
sleep 2
for spec in "$@"; do
  IFS=: read -r app suffix path <<< "$spec"
  id=dev.whiskerrs.shopbench.$suffix
  rm -rf $OUT/$app && mkdir -p $OUT/$app
  xcrun devicectl device uninstall app --device $DEV $id -q > /dev/null 2>&1
  xcrun devicectl device install app --device $DEV "$path" -q > /dev/null
  curl -s -X POST http://127.0.0.1:8787/_reset > /dev/null
  start=$(date +%s)
  TEST_RUNNER_SHOP_BUNDLE_ID=$id TEST_RUNNER_SHOP_API_URL=http://$HOST:8787/api \
    xcodebuild test-without-building -xctestrun $XCTESTRUN -destination "id=$DEV" \
    -only-testing:ShopBenchUITests/JourneyTests/testJourney -resultBundlePath $OUT/$app/journey.xcresult \
    > $OUT/$app/journey.log 2>&1
  code=$?
  curl -s http://127.0.0.1:8787/_stats > $OUT/$app/stats.json
  xcrun xcresulttool export attachments --path $OUT/$app/journey.xcresult --output-path $OUT/$app/attachments > /dev/null 2>&1
  echo "$app exit=$code secs=$(( $(date +%s) - start )) videos=$(ls $OUT/$app/attachments/*.mp4 2>/dev/null | wc -l | tr -d ' ') $(head -c 120 $OUT/$app/stats.json)"
  xcrun devicectl device uninstall app --device $DEV $id -q > /dev/null 2>&1
done
