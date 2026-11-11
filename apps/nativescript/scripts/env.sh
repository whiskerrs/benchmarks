# Shared environment for the build scripts (sourced, not executed).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Puts the `ruby` shim (system Ruby + the xcodeproj gem from ./.gems) first.
export PATH="$ROOT/scripts/bin:$PATH"
cd "$ROOT"
