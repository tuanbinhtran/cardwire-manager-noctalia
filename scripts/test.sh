#!/usr/bin/env sh
# Runs the pure-logic Luau unit tests. Uses `luau` from PATH, $LUAU, or
# downloads the pinned luau CLI release into .tools/ (gitignored).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LUAU_VERSION=0.745
LUAU="${LUAU:-}"
if [ -z "$LUAU" ]; then
  if command -v luau >/dev/null 2>&1; then
    LUAU=luau
  else
    LUAU="$ROOT/.tools/luau"
    if [ ! -x "$LUAU" ]; then
      mkdir -p "$ROOT/.tools"
      curl -fsSL -o "$ROOT/.tools/luau.zip" \
        "https://github.com/luau-lang/luau/releases/download/$LUAU_VERSION/luau-ubuntu.zip"
      unzip -o -q "$ROOT/.tools/luau.zip" luau -d "$ROOT/.tools"
      chmod +x "$LUAU"
    fi
  fi
fi
# One process per suite: the shared harness counts assertions per run.
for suite in "$ROOT"/tests/*.test.luau; do
  "$LUAU" "$suite"
done
