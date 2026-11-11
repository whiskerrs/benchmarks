#!/bin/bash
# Installs what the builds need: the pinned Exact and Ibex checkouts, Bun 1.4.2,
# Exact's toolchains, the app's packages and the Android Hermes bundle.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXACT_COMMIT=fc14919528fb76ca8de3e8c8d9ef91853f923a17
IBEX_COMMIT=a0183568e8229b8243629cdb26cd4a88ac4e2abd

fetch() { # <dir> <url> <commit>
  if [[ ! -d "$1/.git" ]]; then git init -q "$1" && git -C "$1" remote add origin "$2"; fi
  if [[ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" != "$3" ]]; then
    git -C "$1" fetch -q --depth 1 origin "$3" && git -C "$1" checkout -q --detach FETCH_HEAD
  fi
}
fetch "$ROOT/vendor/exact2" https://github.com/expo/exact.git "$EXACT_COMMIT"
fetch "$ROOT/vendor/ibex" https://github.com/expo/ibex.git "$IBEX_COMMIT"

BUN="$HOME/.bun-1.4.2/bin/bun"
if [[ ! -x "$BUN" ]]; then curl -fsSL https://bun.sh/install | BUN_INSTALL="$HOME/.bun-1.4.2" bash -s bun-v1.4.2; fi
export PATH="$HOME/.bun-1.4.2/bin:$PATH"

(cd "$ROOT/vendor/exact2" && bun scripts/exact.mjs setup)
rustup target add --toolchain 1.97.0 aarch64-apple-ios aarch64-apple-ios-sim aarch64-linux-android
(cd "$ROOT/everbloom" && bun install --frozen-lockfile)

# Android's Hermes bundle (no Ibex release ships one): built once from the Ibex checkout.
# Its build needs cmake and ninja; the Android SDK's cmake carries both.
if [[ -z "$(cd "$ROOT/vendor/exact2" && bun scripts/hermes-android.mjs path)" ]]; then
  CMAKE_BIN="$(ls -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/cmake/*/bin 2>/dev/null | sort -V | tail -1)"
  (cd "$ROOT/vendor/exact2" && PATH="$CMAKE_BIN:$PATH" IBEX_DIR="$ROOT/vendor/ibex" bun scripts/hermes-android.mjs build)
fi
