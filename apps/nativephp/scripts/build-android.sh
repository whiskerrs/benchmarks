#!/usr/bin/env bash
# Build the Everbloom Android release APK, signed with the Android debug key.
#
#   scripts/build-android.sh
#   SHOP_API_URL=http://192.168.1.20:8787/api scripts/build-android.sh
#
# SHOP_API_URL (optional) is baked into the bundled app's .env at build time;
# without it the app uses https://apparel-large-catalog.mock.shop/api.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ANDROID_HOME:=$HOME/Library/Android/sdk}"
export ANDROID_HOME
DEBUG_KEYSTORE="${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"

# Create the standard Android debug keystore if this machine has none.
if [ ! -f "$DEBUG_KEYSTORE" ]; then
    mkdir -p "$(dirname "$DEBUG_KEYSTORE")"
    keytool -genkeypair -v -keystore "$DEBUG_KEYSTORE" -storepass android -keypass android \
        -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US"
fi

# native:package bumps NATIVEPHP_APP_VERSION_CODE in .env and the endpoint
# below is written there too; put .env back afterwards.
cp .env .env.build-backup
trap 'mv .env.build-backup .env' EXIT

# Unique build number: the app re-extracts its bundled code only when the
# version or build number changes, so an install over an older build would
# otherwise keep running the old code.
sed -i.tmp "s#^NATIVEPHP_APP_VERSION_CODE=.*#NATIVEPHP_APP_VERSION_CODE=$(date +%s)#" .env && rm -f .env.tmp

if [ -n "${SHOP_API_URL:-}" ]; then
    if grep -q '^SHOP_API_URL=' .env; then
        sed -i.tmp "s#^SHOP_API_URL=.*#SHOP_API_URL=${SHOP_API_URL}#" .env && rm -f .env.tmp
    else
        echo "SHOP_API_URL=${SHOP_API_URL}" >> .env
    fi
fi

# NativePHP bundles the Laravel app (composer --no-dev), compiles plugins,
# runs `gradlew assembleRelease` and signs the APK with the given keystore.
php artisan native:package android \
    --build-type=release \
    --keystore="$DEBUG_KEYSTORE" \
    --keystore-password=android \
    --key-alias=androiddebugkey \
    --key-password=android \
    --no-tty

echo "APK: $PWD/nativephp/android/app/build/outputs/apk/release/app-release.apk"
