#!/usr/bin/env bash
# Downloads the command-line tools used by scripts/check.sh and scripts/test.sh
# into ./.tools (git-ignored). Safe to re-run.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/.tools"
mkdir -p "$TOOLS"
cd "$TOOLS"
fetch() { curl -fsSL -o "$1" "$2"; }
if [ ! -x luau ]; then
	fetch luau.zip https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
	unzip -oq luau.zip && rm luau.zip
fi
if [ ! -x rojo ]; then
	fetch rojo.zip https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-linux-x86_64.zip
	unzip -oq rojo.zip && rm rojo.zip
fi
if [ ! -x luau-lsp ]; then
	fetch lsp.zip https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.70.1/luau-lsp-linux-x86_64.zip
	unzip -oq lsp.zip && rm lsp.zip && chmod +x luau-lsp
fi
if [ ! -f globalTypes.d.luau ]; then
	fetch globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
echo "tools ready in $TOOLS"
