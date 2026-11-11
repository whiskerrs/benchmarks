#!/bin/bash
# Everbloom's Android release APK (Rust at the release profile, Gradle assembleRelease, debug-signed).
# SHOP_API_URL, if set when this runs, is the endpoint the APK uses.
# Result: build/android/Everbloom-release.apk
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/everbloom"
OUT="$ROOT/build/android"
BUN="${BUN:-$HOME/.bun-1.4.2/bin/bun}"
export PATH="$(dirname "$BUN"):$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [[ -z "${JAVA_HOME:-}" && -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi

(cd "$APP_DIR" && EXACT_APP_DIR="$APP_DIR" "$BUN" "$ROOT/vendor/exact2/scripts/agent-android.mjs" build everbloom --apk --release)

mkdir -p "$OUT"
cp "$APP_DIR/target/android/app/outputs/apk/release/app-release.apk" "$OUT/Everbloom-release.apk"
echo "$OUT/Everbloom-release.apk"
