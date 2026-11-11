#!/bin/bash
# Records a cold launch from the Home Screen icon per app (screen recording kept) for the launch video.
#   tools/tap-launch.sh <device udid> <mac LAN IP> <app>:<bundle id suffix>:<device .app> ...
set -u
cd "$(dirname "$0")/.."
DEV=$1 HOST=$2
shift 2
OUT=results/tap-launch
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
  for other in reactnative flutter whisker nsh nativescript exact; do
    xcrun devicectl device uninstall app --device $DEV dev.whiskerrs.shopbench.$other -q > /dev/null 2>&1
  done
  xcrun devicectl device install app --device $DEV "$path" -q > /dev/null
  TEST_RUNNER_SHOP_BUNDLE_ID=$id TEST_RUNNER_SHOP_API_URL=http://$HOST:8787/api \
    xcodebuild test-without-building -xctestrun $XCTESTRUN -destination "id=$DEV" \
    -only-testing:ShopBenchUITests/JourneyTests/testPrepare -resultBundlePath $OUT/$app/prepare.xcresult \
    > $OUT/$app/prepare.log 2>&1 || { echo "$app prepare failed"; continue; }
  TEST_RUNNER_SHOP_BUNDLE_ID=$id TEST_RUNNER_SHOP_API_URL=http://$HOST:8787/api \
    xcodebuild test-without-building -xctestrun $XCTESTRUN -destination "id=$DEV" \
    -only-testing:ShopBenchUITests/JourneyTests/testTapLaunch -resultBundlePath $OUT/$app/tap.xcresult \
    > $OUT/$app/tap.log 2>&1
  code=$?
  xcrun xcresulttool export attachments --path $OUT/$app/tap.xcresult --output-path $OUT/$app/attachments > /dev/null 2>&1
  echo "$app exit=$code videos=$(ls $OUT/$app/attachments/*.mp4 2>/dev/null | wc -l | tr -d ' ')"
  xcrun devicectl device uninstall app --device $DEV $id -q > /dev/null 2>&1
done
