#!/usr/bin/env bash
# Experimental full-game ARM64 link attempt, not a guaranteed successful NRO.
# Run build-recomp-arm64.sh first. Compile the desktop game's real host/game
# sources against libnx SDL2; compiler/linker output identifies porting blockers.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export DEVKITA64="${DEVKITA64:-$DEVKITPRO/devkitA64}"
export PATH="$DEVKITPRO/tools/bin:$DEVKITA64/bin:$DEVKITPRO/portlibs/switch/bin:$PATH"
CC="$DEVKITA64/bin/aarch64-none-elf-gcc"
[[ -x "$CC" ]] || { echo "Missing devkitA64 compiler" >&2; exit 1; }
command -v aarch64-none-elf-pkg-config >/dev/null || {
  echo "Missing devkitPro Switch pkg-config for SDL2" >&2
  exit 1
}
OUT="$HERE/game-build"
mkdir -p "$OUT/host-objects"
[[ -s "$OUT/libsmw-game-core-aarch64.a" && -s "$OUT/libsnesrecomp-hardware-aarch64.a" ]] || {
  echo "First run bash switch-port/build-recomp-arm64.sh" >&2; exit 1;
}
# shellcheck disable=SC2207
SDL_CFLAGS=( $(aarch64-none-elf-pkg-config --cflags sdl2) )
# shellcheck disable=SC2207
SDL_LIBS=( $(aarch64-none-elf-pkg-config --libs sdl2) )
CFLAGS=(
 -std=gnu11 -O2 -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE -ffunction-sections -fdata-sections
 -DSNESRECOMP_TRACE=0 -DSNESRECOMP_ENABLE_MODS=0 -DSNESRECOMP_SDL3=0
 -D__SWITCH__ -DSDL_MAIN_HANDLED -DSNESRECOMP_REVERSE_DEBUG=0
 "-I$ROOT" "-I$ROOT/src" "-I$ROOT/recomp"
 "-I$ROOT/snesrecomp/runner/src"
 "-I$ROOT/snesrecomp/runner/src/desktop"
 "-I$ROOT/snesrecomp/runner/src/snes"
 "-I$DEVKITPRO/libnx/include" "-I$DEVKITPRO/portlibs/switch/include"
 "${SDL_CFLAGS[@]}"
)
# The host game library requires these modules. The adaptive renderer, game
# AOT code and SNES hardware have already been cross-compiled to archives.
host=(
  src/main.c src/config.c src/mod_external_rom_compat.c src/smw_netplay_lobby.c
  src/mods/falcon/falcon_locomotion.c
  src/mods/falcon/captain_falcon_foreign.c
  src/mods/falcon/smw_falcon_combat_policy.c
  src/mods/falcon/smw_falcon_combat_apply.c
  src/mods/falcon/falcon_presentation.c
  src/mods/falcon/smw_falcon_audio.c
  src/mods/falcon/smw_falcon_presentation_runtime.c
  src/mods/smw_falcon_plugin.c
  src/mods/smw_widescreen_plugin.c
  src/mods/smw_msu1_plugin.c
  src/mods/smw_coop_plugin.c
  src/mods/coop/coop_session.c
  src/mods/coop/coop_state.c
  src/mods/coop/coop_guest.c
  src/mods/coop/coop_machine.c
  src/mods/coop/coop_runtime.c
  src/mods/coop/coop_storage.c
  src/mods/coop/coop_simulation.c
  src/mods/coop/coop_terrain.c
  src/mods/coop/coop_presentation.c
  switch-port/smw_switch_input.c
)
# Use game-side host path/launcher and core audio handling from the pinned
# snesrecomp runtime. Some of these are desktop-facing and may still require
# libnx porting; no missing dependency is silently stubbed.
runner_host=(
  framedump.c host_paths.c host_args.c launcher.c launcher_cache.c
  launcher_picker.c keybinds.c snes_overlay_draw.c snes_runahead.c
  snes_savestate_menu.c snes_osd.c snes_rewind.c
  host_mesh.c host_mesh_builder.c guarded_patch.c mod_audio.c
  diagnostics/trace_writer.c diagnostics/replay_writer.c
  desktop/post_mortem.c
)
objs=()
manifest="$OUT/host-compile-manifest.tsv"
: > "$manifest"
for src in "${host[@]}"; do
  [[ -f "$ROOT/$src" ]] || { echo "Missing game source $src" >&2; exit 1; }
  label="${src//\//_}"
  obj="$OUT/host-objects/${label%.c}.o"
  echo "Compiling game host: $src"
  printf '%s\t%s\n' "$ROOT/$src" "$obj" >> "$manifest"
  objs+=("$obj")
done
for src in "${runner_host[@]}"; do
  label="${src//\//_}"
  obj="$OUT/host-objects/runner-${label%.c}.o"
  echo "Compiling runner host: $src"
  printf '%s\t%s\n' "$ROOT/snesrecomp/runner/src/$src" "$obj" >> "$manifest"
  objs+=("$obj")
done
shopt -s nullglob
for src in "$ROOT"/overrides/*/*.c; do
  name="$(basename "${src%.c}")"
  obj="$OUT/host-objects/override-$name.o"
  echo "Compiling SMW override: $src"
  printf '%s\t%s\n' "$src" "$obj" >> "$manifest"
  objs+=("$obj")
done
python3 "$HERE/compile_cached.py" --cc "$CC" --manifest "$manifest" \
  --jobs "${SMW_BUILD_JOBS:-2}" -- "${CFLAGS[@]}"
echo "Linking actual Super Mario World executable ELF"
ELF="$OUT/SuperMarioWorldRecomp-Switch.elf"
"$CC" -fPIE -specs="$DEVKITPRO/libnx/switch.specs" -Wl,--gc-sections \
  -o "$ELF" "${objs[@]}" \
  -Wl,--start-group "$OUT/libsmw-game-core-aarch64.a" \
  "$OUT/libsnesrecomp-hardware-aarch64.a" -Wl,--end-group \
  "${SDL_LIBS[@]}" -lnx -lm
echo "Linked ELF: $ELF"
command -v elf2nro >/dev/null || { echo "Missing elf2nro" >&2; exit 1; }
elf2nro "$ELF" "$OUT/SuperMarioWorldRecomp-Switch.nro"
echo "EXPERIMENTAL GAME NRO LINKED: $OUT/SuperMarioWorldRecomp-Switch.nro"
echo "Hardware boot/gameplay/save validation STILL REQUIRED."
