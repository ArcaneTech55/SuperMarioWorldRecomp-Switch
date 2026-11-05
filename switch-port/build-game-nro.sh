#!/usr/bin/env bash
# End-to-end experimental game build attempt. This is NOT a diagnostic NRO.
# Does not claim an NRO exists until the final cross-link and elf2nro succeed.
set -euo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROM="${1:-$SELF/../../Super Mario World (USA).sfc}"
echo "=== Super Mario World Recomp: real game core + SNES hardware ==="
bash "$SELF/build-recomp-arm64.sh" "$ROM"
echo "=== Super Mario World Recomp: host cross-compile + final ELF/NRO link ==="
bash "$SELF/attempt-game-link.sh"
echo "=== Completed: see switch-port/game-build/SuperMarioWorldRecomp-Switch.nro ==="
