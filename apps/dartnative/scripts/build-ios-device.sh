#!/bin/sh
# Builds the iOS device release app (arm64, Release configuration, Dart AOT).
#
#   DEVELOPMENT_TEAM=ABCDE12345 scripts/build-ios-device.sh   # signed (automatic signing)
#   scripts/build-ios-device.sh                               # unsigned (CODE_SIGNING_ALLOWED=NO)
#
# Output: build/ios-device/Build/Products/Release-iphoneos/Runner.app
#
# `dn build ios` picks a signing identity by itself and does not read
# DEVELOPMENT_TEAM, so dn only writes the build configuration here (Dart
# defines, licence, plugin pods) and xcodebuild does the build. The Dart code
# is AOT-compiled by the Runner target's DartNative build phase.
set -eu
cd "$(dirname "$0")/.."

dn build ios --release --config-only --no-codesign

if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
  set -- DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates
else
  set -- CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
fi

xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios-device \
  -quiet \
  "$@" \
  build

echo "Built build/ios-device/Build/Products/Release-iphoneos/Runner.app"
