#!/usr/bin/env bash
# Static verification: builds the place with Rojo and type-checks every script
# against the Roblox API definitions using luau-lsp.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/.tools"
cd "$ROOT"
[ -x "$TOOLS/luau-lsp" ] || "$ROOT/scripts/bootstrap-tools.sh"
mkdir -p build
"$TOOLS/rojo" build default.project.json -o build/TinyToTitan.rbxlx
"$TOOLS/rojo" sourcemap default.project.json -o sourcemap.json
"$TOOLS/luau-lsp" analyze \
	--definitions="$TOOLS/globalTypes.d.luau" \
	--sourcemap=sourcemap.json \
	--base-luaurc=.luaurc \
	--no-strict-dm-types \
	src "$@"
