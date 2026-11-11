#!/bin/bash
# The benchmarked build: Everbloom for arm64 iOS devices, release (production) mode.
#
#   DEVELOPMENT_TEAM=ABCDE12345 scripts/build-ios-device.sh   signed for that team (automatic signing)
#   scripts/build-ios-device.sh                               no team: code signing disabled (ad-hoc)
#
# Result: build/ios-device/Everbloom.app
#
# Exact assembles and signs its .app itself (no Xcode project).
#
# With DEVELOPMENT_TEAM: Xcode first builds a never-shipped stub app with the same
# bundle id under that team with -allowProvisioningUpdates and
# -allowProvisioningDeviceRegistration, so Xcode's automatic signing creates (or
# refreshes) the team's development profile for the id, registering a connected
# iPhone. Exact's device release build (`ios --device --release --no-install`)
# then signs with that profile and the team's Apple Development identity. Exact
# builds a development-signed device app for a phone this Mac knows, so the
# benchmark iPhone must have been connected to this Mac (xcrun devicectl list
# devices shows it); EXACT_PHONE=<udid|name> picks one of several.
#
# Without DEVELOPMENT_TEAM: Exact's only phone-less device packaging is its
# distribution archive (`--archive --unsigned`, ad-hoc signed, no profile, no
# team), which refuses a bundle without an app icon. For that build only, a
# plain white placeholder icon (scripts/unsigned-placeholder-icon.png) is named
# in app.json and removed again afterwards; the signed build has no icon.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/everbloom"
OUT="$ROOT/build/ios-device"
BUNDLE_ID="dev.whiskerrs.shopbench.exact"
BUN="${BUN:-$HOME/.bun-1.4.2/bin/bun}"
export PATH="$(dirname "$BUN"):$PATH"

mkdir -p "$OUT"
rm -rf "$OUT/Everbloom.app" "$OUT/Everbloom.ipa" "$OUT/Payload"

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  STUB_DD="$OUT/stub-derived"
  xcodebuild -project "$ROOT/scripts/signing-stub/Stub.xcodeproj" -scheme Stub -configuration Release \
    -destination generic/platform=iOS -derivedDataPath "$STUB_DD" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" STUB_BUNDLE_ID="$BUNDLE_ID" build >"$OUT/stub-build.log" 2>&1 \
    || { echo "Xcode could not sign the stub for team $DEVELOPMENT_TEAM; see $OUT/stub-build.log" >&2; exit 1; }
  STUB_APP="$STUB_DD/Build/Products/Release-iphoneos/Stub.app"
  [[ -f "$STUB_APP/embedded.mobileprovision" ]] || { echo "no provisioning profile in the stub build" >&2; exit 1; }
  cp "$STUB_APP/embedded.mobileprovision" "$OUT/team.mobileprovision"
  # The identity Xcode signed the stub with, as the SHA-1 Exact's EXACT_IDENTITY takes.
  IDENTITY="$(codesign -dvvv "$STUB_APP" 2>&1 | sed -n 's/^Authority=\(Apple Development: .*\)$/\1/p' | head -1)"
  SHA1="$(security find-identity -v -p codesigning | grep -F "\"$IDENTITY\"" | head -1 | awk '{print $2}')"
  [[ -n "$SHA1" ]] || { echo "no keychain identity matches \"$IDENTITY\"" >&2; exit 1; }
  (cd "$APP_DIR" && EXACT_IDENTITY="$SHA1" EXACT_PROFILE="$OUT/team.mobileprovision" \
    "$BUN" exact.mjs ios --device --release --no-install)
  BUILT="$(ls -td "$APP_DIR"/target/clients/*/"$BUNDLE_ID"/ios/aarch64-apple-ios/*/production/standalone/Everbloom.app | head -1)"
  ditto "$BUILT" "$OUT/Everbloom.app"
else
  MANIFEST="$APP_DIR/app.json"
  cp "$MANIFEST" "$OUT/app.json.orig"
  cp "$ROOT/scripts/unsigned-placeholder-icon.png" "$APP_DIR/.exact/unsigned-placeholder-icon.png"
  restore() { cp "$OUT/app.json.orig" "$MANIFEST"; rm -f "$OUT/app.json.orig" "$APP_DIR/.exact/unsigned-placeholder-icon.png"; }
  trap restore EXIT
  "$BUN" -e 'const f=process.argv[1]; const m=JSON.parse(await Bun.file(f).text());
    m.icons=[{src: ".exact/unsigned-placeholder-icon.png", sizes: "1024x1024", type: "image/png"}];
    await Bun.write(f, JSON.stringify(m, null, 2) + "\n");' "$MANIFEST"
  (cd "$APP_DIR" && "$BUN" exact.mjs ios --device --release --archive "$OUT/Everbloom.ipa" --unsigned)
  (cd "$OUT" && ditto -x -k Everbloom.ipa . && mv Payload/*.app "$OUT/Everbloom.app" && rm -rf Payload)
fi

echo "$OUT/Everbloom.app"
