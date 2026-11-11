#!/bin/bash
# Everbloom for the iOS Simulator in release (production) mode: Exact's `ios --release`,
# the build that ships, for the simulator. Result: build/ios-simulator/Everbloom.app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/everbloom"
OUT="$ROOT/build/ios-simulator"
BUN="${BUN:-$HOME/.bun-1.4.2/bin/bun}"
export PATH="$(dirname "$BUN"):$PATH"

# Builds, and installs on the booted iPhone simulator (or EXACT_SIM / --sim).
(cd "$APP_DIR" && "$BUN" exact.mjs ios --release "$@")

BUILT="$(ls -td "$APP_DIR"/target/clients/*/dev.whiskerrs.shopbench.exact/ios-simulator/*/*/production/standalone/Everbloom.app | head -1)"
mkdir -p "$OUT"
rm -rf "$OUT/Everbloom.app"
ditto "$BUILT" "$OUT/Everbloom.app"
echo "$OUT/Everbloom.app"
