#!/usr/bin/env bash
# Runs the headless Luau unit tests (tests/*.spec.luau).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -x "$ROOT/.tools/luau" ] || "$ROOT/scripts/bootstrap-tools.sh"
node "$ROOT/tools/test/runner.mjs" "$@"
