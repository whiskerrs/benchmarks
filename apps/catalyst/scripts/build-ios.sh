#!/bin/sh
# Builds the iOS app in Release (optimised, bundled web app, no dev server).
#   scripts/build-ios.sh device     -> build/ios-device/Build/Products/Release-iphoneos/Everbloom.app
#   scripts/build-ios.sh simulator  -> build/ios-sim/Build/Products/Release-iphonesimulator/Everbloom.app
# Device builds sign automatically with $DEVELOPMENT_TEAM, or build unsigned
# (CODE_SIGNING_ALLOWED=NO) when it is unset.
set -eu
cd "$(dirname "$0")/.."
TARGET="${1:-device}"
[ -f ios/Everbloom/www/index.html ] || node scripts/bundle-web.mjs

case "$TARGET" in
device)
    if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
        SIGNING="DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates"
    else
        echo "DEVELOPMENT_TEAM is not set: building unsigned (CODE_SIGNING_ALLOWED=NO)"
        SIGNING="CODE_SIGNING_ALLOWED=NO"
    fi
    # shellcheck disable=SC2086
    xcodebuild -project ios/Everbloom.xcodeproj -scheme Everbloom -configuration Release \
        -sdk iphoneos -destination generic/platform=iOS -derivedDataPath build/ios-device \
        $SIGNING build
    echo "Built build/ios-device/Build/Products/Release-iphoneos/Everbloom.app"
    ;;
simulator)
    xcodebuild -project ios/Everbloom.xcodeproj -scheme Everbloom -configuration Release \
        -sdk iphonesimulator -destination "generic/platform=iOS Simulator" -derivedDataPath build/ios-sim build
    echo "Built build/ios-sim/Build/Products/Release-iphonesimulator/Everbloom.app"
    ;;
*)
    echo "usage: scripts/build-ios.sh device|simulator" >&2
    exit 2
    ;;
esac
