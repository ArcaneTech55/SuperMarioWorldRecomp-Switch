#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export DEVKITA64="${DEVKITA64:-$DEVKITPRO/devkitA64}"
export PATH="$DEVKITPRO/tools/bin:$DEVKITA64/bin:$DEVKITPRO/portlibs/switch/bin:$PATH"
if [[ ! -f "$DEVKITPRO/libnx/switch_rules" ]]; then
  echo "ERROR: libnx missing from $DEVKITPRO" >&2
  exit 1
fi
if ! command -v aarch64-none-elf-gcc >/dev/null 2>&1; then
  echo "ERROR: devkitA64 cross compiler not found." >&2
  exit 1
fi
if ! command -v aarch64-none-elf-pkg-config >/dev/null 2>&1; then
  echo "ERROR: Switch pkg-config missing. Ensure switch-sdl2 and portlibs are installed." >&2
  exit 1
fi
make -C "$ROOT" -j4
test -s "$ROOT/smw-recomp-platform-check.nro"
echo "Switch platform diagnostic: $ROOT/smw-recomp-platform-check.nro"
echo "Install to SD:/switch/smw-recomp-platform-check.nro"
echo "THIS IS NOT THE GAME: recomp renderer/guest program are not linked."
