#!/usr/bin/env bash
# Stage 1 of the actual recompilation game build: produce an ARM64 game-code archive.
# No fake NRO output. Requires the user's clean ROM, devkitA64, and pinned submodules.
set -euo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/.." && pwd)"
ROM="${1:-$ROOT/../Super Mario World (USA).sfc}"
DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
DEVKITA64="${DEVKITA64:-$DEVKITPRO/devkitA64}"
export DEVKITPRO DEVKITA64
export PATH="$DEVKITPRO/tools/bin:$DEVKITA64/bin:$DEVKITPRO/portlibs/switch/bin:$PATH"
CC="$DEVKITA64/bin/aarch64-none-elf-gcc"
AR="$DEVKITA64/bin/aarch64-none-elf-ar"
# The Switch SDL2 headers are typically in portlibs/switch/include/SDL2.
# SDL_compat.h uses <SDL.h>, so ask the target pkg-config for its include
# directory rather than relying on the generic portlibs include directory.
if ! command -v aarch64-none-elf-pkg-config >/dev/null 2>&1; then
  echo "Missing Switch pkg-config. Install the devkitPro switch-sdl2 portlib." >&2
  exit 1
fi
if ! aarch64-none-elf-pkg-config --exists sdl2; then
  echo "Switch SDL2 package not found. Install switch-sdl2 with devkitPro pacman." >&2
  exit 1
fi
read -r -a SDL_CFLAGS <<< "$(aarch64-none-elf-pkg-config --cflags sdl2)"

BUILD="$SELF/game-build"
OBJECTS="$BUILD/objects"
EXPECTED_SHA1="6b47bb75d16514b6a476aa0c73a683a2a4c18765"

fail() { echo "SMW game-core build: $*" >&2; exit 1; }
[[ -f "$ROM" ]] || fail "ROM not found: $ROM"
[[ -x "$CC" ]] || fail "Missing ARM64 compiler: $CC"
[[ -x "$AR" ]] || fail "Missing ARM64 archiver: $AR"
[[ -d "$ROOT/snesrecomp/runner/src" ]] || fail "Missing submodule: run git submodule update --init --recursive"
command -v cargo >/dev/null 2>&1 || fail "The pinned native analyzer is written in Rust. Install Rust/Cargo (https://rustup.rs/) and rerun."

actual="$(shasum -a 1 "$ROM" | awk '{print $1}')"
[[ "$actual" == "$EXPECTED_SHA1" ]] || fail "Unsupported ROM SHA-1 $actual"

# regen.sh requires smw.sfc in repository root. Never commit this copyrighted file.
# We avoid touching a preexisting ROM; if one is present it must match.
if [[ -f "$ROOT/smw.sfc" ]]; then
  existing="$(shasum -a 1 "$ROOT/smw.sfc" | awk '{print $1}')"
  [[ "$existing" == "$EXPECTED_SHA1" ]] || fail "A different smw.sfc already exists in the repository root"
  created_rom=0
else
  cp "$ROM" "$ROOT/smw.sfc"
  created_rom=1
fi
cleanup() {
  if [[ "$created_rom" == 1 ]]; then rm -f "$ROOT/smw.sfc"; fi
}
trap cleanup EXIT

mkdir -p "$OBJECTS"
echo "[1/4] Regenerating SMW 65816 C code from original owner ROM"
(
  cd "$ROOT"
  SNESRECOMP_ANALYSIS_BACKEND=native \
     bash tools/regen.sh --stock --no-tests
  python3 tools/apply_renderer_hooks.py --gen-dir src/gen
  python3 tools/apply_coop_hooks.py --gen-dir src/gen
)
shopt -s nullglob
generated=("$ROOT"/src/gen/*.c)
(( ${#generated[@]} > 0 )) || fail "Generator produced no src/gen/*.c"
echo "[2/4] Compiling ${#generated[@]} genuine AOT translation units for ARM64"
CFLAGS=(
  -std=gnu11 -O2 -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE -ffunction-sections -fdata-sections
  -DSNESRECOMP_TRACE=0 -DSNESRECOMP_ENABLE_MODS=0
  -DSNESRECOMP_SDL3=0 -D__SWITCH__ -DSNESRECOMP_REVERSE_DEBUG=0
  "-I$ROOT" "-I$ROOT/src" "-I$ROOT/recomp" "-I$ROOT/snesrecomp/runner/src"
  "-I$ROOT/snesrecomp/runner/src/snes"
  "-I$ROOT/snesrecomp/runner/src/desktop"
  "-I$DEVKITPRO/libnx/include"
  "-I$DEVKITPRO/portlibs/switch/include"
  "${SDL_CFLAGS[@]}"
)
objects=()
manifest="$BUILD/game-compile-manifest.tsv"
: > "$manifest"
for src in "${generated[@]}"; do
  base="$(basename "${src%.c}")"
  obj="$OBJECTS/gen-$base.o"
  printf '%s\t%s\n' "$src" "$obj" >> "$manifest"
  objects+=("$obj")
done
echo "[3/4] Compiling handwritten SMW engine and adaptive widescreen components"
manual=(
  "$ROOT/src/smw_00.c"
  "$ROOT/src/smw_video.c"
  "$ROOT/src/smw_renderer.c"
  "$ROOT/src/smw_renderer_hooks.c"
  "$ROOT/src/smw_rtl.c"
  "$ROOT/src/smw_cpu_infra.c"
  "$ROOT/src/smw_spc_player.c"
  "$ROOT/src/gen_stubs.c"
  "$ROOT/src/foreign_controller.c"
  "$ROOT/src/mod_audio.c"
)
for src in "${manual[@]}"; do
  name="$(basename "${src%.c}")"
  obj="$OBJECTS/hand-$name.o"
  printf '%s\t%s\n' "$src" "$obj" >> "$manifest"
  objects+=("$obj")
done
python3 "$SELF/compile_cached.py" --cc "$CC" --manifest "$manifest" \
  --jobs "${SMW_BUILD_JOBS:-2}" -- "${CFLAGS[@]}"
echo "[4/4] Archiving real SMW game code"
OUT="$BUILD/libsmw-game-core-aarch64.a"
rm -f "$OUT"
"$AR" rcs "$OUT" "${objects[@]}"
[[ -s "$OUT" ]] || fail "Archive is missing"
echo
echo "PASS: $OUT"
echo "AArch64 game-code archive built; NOT a playable .nro."
echo "Next linkage must include snesrecomp runner, SDL2, game host, APU, SRAM and libnx."
