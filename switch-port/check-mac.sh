#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
ROM="${1:-}"
echo "Checking SuperMarioWorldRecomp-Switch dependencies..."
for tool in git cmake python3 cc; do
  command -v "$tool" >/dev/null || { echo "Missing: $tool"; exit 1; }
done
if [ -n "$ROM" ]; then
  test -f "$ROM" || { echo "ROM does not exist: $ROM"; exit 1; }
  actual="$(shasum -a 1 "$ROM" | awk '{print $1}')"
  expected="6b47bb75d16514b6a476aa0c73a683a2a4c18765"
  if [ "$actual" != "$expected" ]; then
    echo "Unexpected ROM SHA-1: $actual"
    exit 1
  fi
  echo "Original Super Mario World (USA) ROM verified."
fi
if [ ! -d "$DEVKITPRO" ]; then
  echo "Missing DEVKITPRO: $DEVKITPRO"
  exit 1
fi
if [ ! -f "$DEVKITPRO/libnx/switch_rules" ]; then
  echo "Missing libnx Switch rules; ensure switch-dev is installed."
  exit 1
fi
echo "devkitPro/libnx found at $DEVKITPRO"
tmp_bin="$(mktemp "${TMPDIR:-/tmp}/smw-video.XXXXXXXX")"
trap 'rm -f "$tmp_bin"' EXIT
cc -std=c11 -Wall -Wextra -Werror -pedantic \
  "$ROOT/switch-port/smw_switch_video.c" \
  "$ROOT/switch-port/tests/test_video.c" \
  -o "$tmp_bin"
"$tmp_bin"
save_bin="$(mktemp "${TMPDIR:-/tmp}/smw-save.XXXXXXXX")"
trap 'rm -f "$save_bin"' EXIT
cc -std=gnu11 -Wall -Wextra -Werror \
  "$ROOT/switch-port/smw_switch_save.c" \
  "$ROOT/switch-port/tests/test_save.c" \
  -o "$save_bin"
"$save_bin"
echo "Switch platform diagnostic build command: bash switch-port/build-platform-check.sh"
echo "NOTE: the actual recomp gameplay target remains unported."
