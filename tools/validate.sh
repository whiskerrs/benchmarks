#!/bin/bash
# Runs the journey on the simulator for each app against the replay server and keeps the runner log
# and replay stats under results/validation/<app>/.
#   tools/validate.sh <record|serve> <simulator udid> <app>:<bundle id suffix>:<simulator .app> ...
set -u
cd "$(dirname "$0")/.."
MODE=$1 SIM=$2
shift 2
OUT=results/validation
XCTESTRUN=$(ls tools/runner/build/sim/Build/Products/*.xctestrun | head -1)
mkdir -p $OUT
python3 tools/replay/replay.py $MODE --port 8787 --log $OUT/replay-$MODE.log > $OUT/replay-$MODE.stdout 2>&1 &
REPLAY=$!
trap 'kill $REPLAY' EXIT
sleep 2
for spec in "$@"; do
  IFS=: read -r app suffix path <<< "$spec"
  mkdir -p $OUT/$app
  rm -rf $OUT/$app/$MODE.xcresult
  xcrun simctl uninstall $SIM dev.whiskerrs.shopbench.$suffix
  xcrun simctl install $SIM "$path"
  curl -s -X POST http://127.0.0.1:8787/_reset > /dev/null
  start=$(date +%s)
  TEST_RUNNER_SHOP_BUNDLE_ID=dev.whiskerrs.shopbench.$suffix TEST_RUNNER_SHOP_API_URL=http://127.0.0.1:8787/api \
    xcodebuild test-without-building -xctestrun "$XCTESTRUN" -destination "id=$SIM" \
    -only-testing:ShopBenchUITests/JourneyTests/testJourney -resultBundlePath $OUT/$app/$MODE.xcresult \
    > $OUT/$app/$MODE.log 2>&1
  code=$?
  curl -s http://127.0.0.1:8787/_stats > $OUT/$app/$MODE-stats.json
  echo "$app $MODE exit=$code secs=$(( $(date +%s) - start )) $(head -c 200 $OUT/$app/$MODE-stats.json)"
  xcrun simctl terminate $SIM dev.whiskerrs.shopbench.$suffix 2>/dev/null
done
