#!/bin/sh
# Simulator verification: runs the XCUITest flows in ios/EverbloomUITests against
# the Release simulator build. Screenshots land in /tmp/eb-shots.
# Run scripts/bundle-web.mjs first. Usage: scripts/verify-ios.sh ["iPhone 17 Pro"]
cd "$(dirname "$0")/.." || exit 1
SIM="${1:-iPhone 17 Pro}"
rm -f /tmp/eb-need-server
rm -rf /tmp/eb-shots
# testMainFlows talks to this forwarder through SHOP_API_URL.
node scripts/forward-server.mjs 8789 &
FORWARDER=$!
# testErrorAndRetry starts with nothing on 8788, then asks for the forwarder there.
( while [ ! -f /tmp/eb-need-server ]; do sleep 0.5; done
  exec node scripts/forward-server.mjs 8788 ) &
WATCHER=$!
xcodebuild -project ios/Everbloom.xcodeproj -scheme Everbloom -configuration Release \
  -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath build/ios-test test
STATUS=$?
kill "$FORWARDER" "$WATCHER" 2>/dev/null
pkill -f "forward-server.mjs 8788" 2>/dev/null
exit $STATUS
