#!/bin/bash
# Installs JS dependencies and the xcodeproj gem used by the NativeScript CLI.
set -euo pipefail
source "$(dirname "$0")/env.sh"
npm ci
/usr/bin/gem install --install-dir "$ROOT/.gems" --no-document xcodeproj -v 1.28.1
