#!/bin/bash
# iOS Simulator Release build (production webpack bundle, Release configuration).
set -euo pipefail
source "$(dirname "$0")/env.sh"
npx ns prepare ios --release
# NativeScript names the Xcode project after the project directory.
PROJ="$(basename platforms/ios/*.xcodeproj .xcodeproj)"
xcodebuild -project "platforms/ios/$PROJ.xcodeproj" -scheme "$PROJ" \
  -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/ios-sim CODE_SIGNING_ALLOWED=NO build
rm -rf "build/ios-sim/Everbloom.app"
ditto "build/ios-sim/Build/Products/Release-iphonesimulator/$PROJ.app" "build/ios-sim/Everbloom.app"
echo "Built: $ROOT/build/ios-sim/Everbloom.app"
