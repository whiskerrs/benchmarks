#!/usr/bin/env bash
# Build the Everbloom iOS app.
#
#   scripts/build-ios.sh simulator   # iOS Simulator .app (arm64)
#   scripts/build-ios.sh device      # iOS device release .app (arm64)
#
# Device builds are signed automatically with the team in $DEVELOPMENT_TEAM;
# with it unset, code signing is disabled (CODE_SIGNING_ALLOWED=NO).
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-device}"

# Every build gets a unique build number. A NativePHP app re-extracts its
# bundled Laravel code only when the version or build number changes, so an
# install over an older build would otherwise keep running the old code.
export NATIVEPHP_APP_VERSION_CODE="${NATIVEPHP_APP_VERSION_CODE:-$(date +%s)}"

# 1. NativePHP: configure the Xcode project (bundle id, display name,
#    Info.plist, plugins, icons, CocoaPods/SPM), bundle the Laravel app in
#    release mode (composer --no-dev, optimized autoloader) and build the
#    simulator app.
php artisan native:build --release --simulated --no-tty

SIM_APP="$PWD/nativephp/ios/build/Build/Products/Debug-iphonesimulator/NativePHP-simulator.app"
if [ "$MODE" = "simulator" ]; then
    echo "Simulator app: $SIM_APP"
    exit 0
fi

# 2. Xcode: Release configuration for generic arm64 iOS devices, reusing the
#    bundle staged in step 1 (NATIVEPHP_CLI_BUILD skips NativePHP's own
#    re-bundling build phase).
if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
    SIGNING=(CODE_SIGN_STYLE=Automatic "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM" -allowProvisioningUpdates)
else
    SIGNING=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO "CODE_SIGN_IDENTITY=")
fi

cd nativephp/ios
NATIVEPHP_CLI_BUILD=1 xcodebuild \
    -workspace NativePHP.xcworkspace \
    -scheme NativePHP \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath build \
    -skipPackagePluginValidation \
    "${SIGNING[@]}" \
    build

echo "Device app: $PWD/build/Build/Products/Release-iphoneos/NativePHP.app"
