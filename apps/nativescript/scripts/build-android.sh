#!/bin/bash
# Android release APK, signed with the Android debug keystore.
# Optional: SHOP_API_URL=http://192.168.1.20:8787/api to bake in another endpoint.
set -euo pipefail
source "$(dirname "$0")/env.sh"
KEYSTORE="${ANDROID_DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
if [ ! -f "$KEYSTORE" ]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkeypair -v -keystore "$KEYSTORE" -storepass android -alias androiddebugkey \
    -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
fi
npx ns build android --release \
  --key-store-path "$KEYSTORE" --key-store-password android \
  --key-store-alias androiddebugkey --key-store-alias-password android \
  --copy-to build/android/everbloom-release.apk
echo "Built: $ROOT/build/android/everbloom-release.apk"
