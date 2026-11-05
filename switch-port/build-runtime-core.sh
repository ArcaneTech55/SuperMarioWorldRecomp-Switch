#!/usr/bin/env bash
# Cross-compile the real snesrecomp interpreter/PPU/APU runtime, not test-tone code.
# Builds an ARM64 archive. Linking with the game host is a separate phase.
set -euo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/.." && pwd)"
export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export DEVKITA64="${DEVKITA64:-$DEVKITPRO/devkitA64}"
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

[[ -x "$CC" && -x "$AR" ]] || { echo "devkitA64 cross-compiler/archiver missing" >&2; exit 1; }
RUNNER="$ROOT/snesrecomp/runner/src"
[[ -d "$RUNNER/snes" ]] || { echo "Missing snesrecomp submodule" >&2; exit 1; }
OBJ="$SELF/game-build/runtime-objects"
mkdir -p "$OBJ"
flags=(
  -std=gnu11 -O2 -ffunction-sections -fdata-sections
  -DSNESRECOMP_TRACE=0 -DSNESRECOMP_ENABLE_MODS=0
  -DSNESRECOMP_SDL3=0 -D__SWITCH__
  "-I$ROOT/src" "-I$ROOT/recomp" "-I$RUNNER"
  "-I$RUNNER/snes" "-I$RUNNER/desktop"
  "-I$DEVKITPRO/libnx/include"
  "-I$DEVKITPRO/portlibs/switch/include"
  "${SDL_CFLAGS[@]}"
)
sources=(
  common_cpu_infra.c common_rtl.c widescreen.c recomp_hw.c
  cpu_state.c program_module.c execution_mode.c
  rom_image_verify.c rom_identity.c sha1.c crc32.c sha256.c
  snapshot_guard.c rom_patch.c
  generic_frame_driver.c beam_frame_driver.c
  content_variant.c variant_selector.c
  cpu_trace.c audio_trace.c ppu_dma_trace.c
  host_report.c state_dump.c util.c
)
hardware=(
  apu.c cart.c cpu.c dma.c dsp.c dsp1.c dsp1_hle.c
  joypad.c audio_shadow.c dsp_shadow.c msu1.c color_lut.c
  ppu.c ppu_legacy.c sa1.c sdd1.c ws_shadow.c
  snes.c snes_other.c spc.c superfx.c cx4.c
  interp816.c tier2_capture.c interp_bridge.c
)
objs=()
for name in "${sources[@]}"; do
  # host_report.c uses the Unix uname API, which libnx lacks.
  # Compile a fork-local implementation while leaving snesrecomp pinned.
  if [[ "$name" == "host_report.c" ]]; then
    src="$SELF/compat/host_report.c"
  else
    src="$RUNNER/$name"
  fi
  [[ -f "$src" ]] || { echo "Missing runtime file: $src" >&2; exit 1; }
  obj="$OBJ/runtime-${name%.c}.o"
  echo "ARM64 runtime: $name"
  "$CC" "${flags[@]}" -c "$src" -o "$obj"
  objs+=("$obj")
done
for name in "${hardware[@]}"; do
  src="$RUNNER/snes/$name"
  [[ -f "$src" ]] || { echo "Missing SNES hardware file: $src" >&2; exit 1; }
  obj="$OBJ/snes-${name%.c}.o"
  echo "ARM64 hardware: $name"
  "$CC" "${flags[@]}" -c "$src" -o "$obj"
  objs+=("$obj")
done
out="$SELF/game-build/libsnesrecomp-hardware-aarch64.a"
rm -f "$out"
"$AR" rcs "$out" "${objs[@]}"
echo "PASS: $out"
echo "Runtime/hardware ARM64 archive, not a linked homebrew NRO."
