#!/usr/bin/env bash
# Single-entry build for *real* Super Mario World recompiled code and SNES hardware.
# Cross-compiles two ARM64 static libraries and creates a link-dependency audit.
# A final .nro requires a completed libnx host + library link stage.
set -euo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/.." && pwd)"
export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export DEVKITA64="${DEVKITA64:-$DEVKITPRO/devkitA64}"
export PATH="$DEVKITPRO/tools/bin:$DEVKITA64/bin:$DEVKITPRO/portlibs/switch/bin:$PATH"
ROM="${1:-$ROOT/../Super Mario World (USA).sfc}"
bash "$SELF/build-game-core.sh" "$ROM"
bash "$SELF/build-runtime-core.sh"
NM="$DEVKITA64/bin/aarch64-none-elf-nm"
if [[ -x "$NM" ]]; then
  out="$SELF/game-build"
  "$NM" -u "$out/libsmw-game-core-aarch64.a" > "$out/smw-unresolved-symbols.txt"
  "$NM" -u "$out/libsnesrecomp-hardware-aarch64.a" > "$out/runtime-unresolved-symbols.txt"
  echo "Unresolved cross-archive references listed in: $out/*unresolved-symbols.txt"
fi
echo
echo "ARM64 game/runner source compilation stage completed."
echo "Do not treat these libraries as a playable .nro: desktop-to-libnx host linkage remains."
