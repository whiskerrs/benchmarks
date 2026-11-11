#!/bin/bash
# iOS device (arm64) Release build. Signs automatically with $DEVELOPMENT_TEAM;
# without it, builds with code signing disabled.
set -euo pipefail
source "$(dirname "$0")/env.sh"
npx ns prepare ios --release
SIGNING=(CODE_SIGNING_ALLOWED=NO)
if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
  SIGNING=(-allowProvisioningUpdates CODE_SIGN_STYLE=Automatic "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi
# NativeScript names the Xcode project after the project directory.
PROJ="$(basename platforms/ios/*.xcodeproj .xcodeproj)"
xcodebuild -project "platforms/ios/$PROJ.xcodeproj" -scheme "$PROJ" \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios-device "${SIGNING[@]}" build
rm -rf "build/ios-device/Everbloom.app"
ditto "build/ios-device/Build/Products/Release-iphoneos/$PROJ.app" "build/ios-device/Everbloom.app"
echo "Built: $ROOT/build/ios-device/Everbloom.app"
