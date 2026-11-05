# Super Mario World Recomp — Nintendo Switch (experimental port)

This branch ports the desktop [mstan/SuperMarioWorldRecomp](https://github.com/mstan/SuperMarioWorldRecomp) toward native Switch execution. Upstream is under PolyForm Noncommercial 1.0.0.

## Confirmed local setup

A clean original USA `Super Mario World (USA).sfc` (SHA-1 `6b47bb75d16514b6a476aa0c73a683a2a4c18765`) and a functioning `/opt/devkitpro` were verified by the user's Terminal. Do **not** upload or commit the ROM.

## Platform modules added

- `smw_switch_video.[ch]`: SDL2 ARGB8888 presenter for an expanded 342×224 widescreen framebuffer (not a 256px stretched image)
- `smw_switch_input.[ch]`: libnx Joy-Con and Pro Controller polling, mapped to SNES button bits
- `smw_switch_audio.[ch]`: SDL2 queued signed 16-bit stereo PCM
- `smw_switch_save.[ch]`: flush-and-rename SD file read/write API, with length checks
- `switch_smoke_main.c`: **diagnostic application**, drawing a moving 342×224 test grid while testing controller, PCM and storage paths
- `Makefile`: cross-compiles the diagnostic into `smw-recomp-platform-check.nro`

These interfaces are **not wired into the original recompilation game's CPU/PPU/APU**. Saving the diagnostic counter is not the game's save system. A generated diagnostic .nro is **not a playable Super Mario World port**.

## Build on macOS (devkitPro and Switch SDL2 installed)

```bash
cd ~/Desktop/SMW-Switch/SuperMarioWorldRecomp-Switch
git pull origin switch-port
git submodule update --init --recursive
bash switch-port/check-mac.sh "../Super Mario World (USA).sfc"
bash switch-port/build-platform-check.sh
```

The last command attempts to produce `switch-port/smw-recomp-platform-check.nro`. If it compiles successfully, copy to `sdmc:/switch/smw-recomp-platform-check.nro` and launch via Homebrew Menu. Left/right scroll the grid, B plays a quiet diagnostic tone, and X exercises SD write (file `sdmc:/switch/smw-recomp/platform-check.dat`).

**No Switch hardware or cross-compiler is accessible inside the assistant environment, so this target is not claimed to compile or boot until tested on the user's installed toolchain.** Share the first compile error if it fails. In particular, this target depends on devkitPro's Switch SDL2 port and its pkg-config metadata.

## Blockers to a *playable game*

- Refactor the desktop OpenGL/launcher-specific engine initialization and resources.
- Cross-compile the generated AOT SNES game code + snesrecomp runner and required dependencies for aarch64/libnx.
- Connect `SmwRendererDraw` output to `smw_switch_video_present`.
- Connect the platform SNES button bits to the guest controller callback.
- Feed the actual guest APU PCM to `smw_switch_audio_push`, and guest SRAM into the persistent save API.
- Test runtime correctness, audio latency, saving, transitions and widescreen enemy spawning on physical Switch.

The native aspect goal is 16:9 without distortion, using the upstream adaptive renderer at approximately 342×224 logical pixels.


## Latest work: game renderer bridge and cross-link fix

- Fixed the diagnostic Makefile to link through the devkitA64 C compiler driver rather than the host macOS `ld`. The previous failure `ld: unknown option: -specs=/opt/devkitpro/libnx/switch.specs` was a build-script error.
- Added `smw_switch_engine_bridge.[ch]`: a **game-facing** adapter that selects the real upstream 342x224 adaptive viewport and calls the existing `RtlDrawPpuFrame` game renderer. **It is not linked to the diagnostic NRO** because it requires the full generated 65816 guest program and snesrecomp runner.

After pulling, build the diagnostic with:

```sh
cd ~/Desktop/SMW-Switch/SuperMarioWorldRecomp-Switch
git pull origin switch-port
make -C switch-port clean
bash switch-port/build-platform-check.sh
```

A successful diagnostic NRO tests platform services only. Building the **playable game** is still blocked on cross-compiling the recomp runtime and linking/initializing the generated guest game; do not rename the diagnostic and assume it runs SMW.

## Game entrypoint integration (in progress)

Unlike the `switch-port/switch_smoke_main.c` diagnostic, these edits are in the actual desktop game's `src/main.c`, conditional on `__SWITCH__`:

- `src/switch_impl.h` initializes libnx SD access, creates `sdmc:/switch/smw-recomp/`, and establishes the game working directory there.
- The game selects `smw.sfc` or `Super Mario World (USA).sfc` from that folder without opening a desktop file picker.
- The game's **existing** `RtlReadSram` / `RtlWriteSram` functions use their normal `saves/` path under that SD working directory. Do not confuse platform-check.dat with actual game saves.
- Joystick polling feeds Joy-Con / Pro Controller state into `g_pad_buttons` in the running game's main loop.
- SDL2 is chosen for the actual game instead of the desktop OpenGL renderer. The existing SNES-SPC-to-SDL audio callback is configured for 48 kHz stereo and can resample according to the obtained audio device format.
- The game main loop respects `appletMainLoop()` so it can leave gameplay via the normal homebrew lifecycle.
- TRACE-enabled developer builds limit trace ring buffers to low-memory settings.

### SD card layout expected by the game entrypoint

```text
sdmc:/switch/smw-recomp/
  smw.sfc                 # Your own USA ROM, never commit it to GitHub
  config.ini              # Optional game configuration
  saves/
    save.srm              # Written by the game's existing SRAM routines
```

**The project still lacks a complete libnx build target for the generated 65816 game, the snesrecomp runner and their desktop library dependencies. The game entrypoint changes have not been cross-compiled or tested on the Switch.** The diagnostic `Makefile` is still separate and does not provide a game build.

## New: cross-compiling the actual game and SNES hardware for Switch

The repository now includes a non-diagnostic cross-build pipeline for the
**actual recompiled Super Mario World game code** and the **snesrecomp
SNES CPU/PPU/APU/interpreter core**.

Run from your existing clone:

```bash
cd ~/Desktop/SMW-Switch/SuperMarioWorldRecomp-Switch
git pull origin switch-port
bash switch-port/build-recomp-arm64.sh "../Super Mario World (USA).sfc"
```

The script verifies the ROM, regenerates untracked `src/gen/` output,
applies required game renderer hooks, compiles generated/handwritten game
units with devkitA64 and compiles the pinned SNES hardware/runner core. If
the compiler accepts all selected units, it produces:

- `switch-port/game-build/libsmw-game-core-aarch64.a`
- `switch-port/game-build/libsnesrecomp-hardware-aarch64.a`
- `switch-port/game-build/{smw,runtime}-unresolved-symbols.txt` (cross-link audit)

**This is an intermediary ARM64 source-compile target, not the final game NRO.**
It does not compile every desktop host subsystem (renderer window lifecycle,
launcher/UI, game startup's complete host dependencies, mods, C++ host tools,
game audio/storage glue) and does not perform the final link. Expect the first
cross-compiler error to identify compatibility work; those errors are not
silently suppressed.

This build has not been run on a real Switch toolchain by the assistant;
the user's M2 Mac has the prerequisite cross compiler. The original
`switch-port/Makefile` is still a *separate platform diagnostic* and must
not be mistaken for the game target.

## Experimental final ELF/NRO link target

A new `build-game-nro.sh` script goes beyond the ARM64 archives: it
cross-compiles the original recomp game host sources and then attempts to
link their symbols with the generated game and SNES hardware code as
`SuperMarioWorldRecomp-Switch.elf`. If and ONLY if that link succeeds,
it invokes `elf2nro` to produce the playable-game candidate
`switch-port/game-build/SuperMarioWorldRecomp-Switch.nro`.

```bash
cd ~/Desktop/SMW-Switch/SuperMarioWorldRecomp-Switch
git pull origin switch-port
bash switch-port/build-game-nro.sh "../Super Mario World (USA).sfc"
```

**This is an unverified experimental full-game cross-build attempt.** The
upstream launcher, mod/plugin code, C++ dependencies, and desktop-oriented
host interfaces are not all certified libnx-compatible. The script aborts
on the first genuine compiler or linker error; it will NOT output a fake
NRO or substitute the platform-check binary. The ARM64 compiler toolchain
is installed on the user's Mac but unavailable in the assistant container,
so no successful full link or hardware boot has been verified.

## libnx compatibility: host report

The pinned SNES runtime `host_report.c` includes `sys/utsname.h` and calls
`uname()`, which are not supplied by devkitPro/libnx. The
`build-runtime-core.sh` target now substitutes
`switch-port/compat/host_report.c`, a copy of the pinned implementation with
only Switch-specific OS identification changed. It retains the rest of the
host diagnostics and does not modify the `snesrecomp` git submodule.

After pulling, restart the runtime stage directly (the successful ARM64 game
archive from the earlier stage is reusable):

```sh
cd ~/Desktop/SMW-Switch/SuperMarioWorldRecomp-Switch
git pull origin switch-port
bash switch-port/build-runtime-core.sh
```

This source adaptation is not yet verified to complete the runtime build; any
further missing POSIX APIs will require similar genuine libnx adaptations.

## ARM64 final-link fixes (Nov 5, 2026)

When both `libsmw-game-core-aarch64.a` and
`libsnesrecomp-hardware-aarch64.a` compile but `attempt-game-link.sh`
reports unresolved symbols, update to `switch-port` and **rebuild both
archives** before linking again. The runtime previously compiled with reverse
debug hooks enabled by an upstream default; the production Switch build now
explicitly sets `SNESRECOMP_REVERSE_DEBUG=0` throughout. Both libraries
must be regenerated with consistent flags.

The final-link target now compiles `smw_switch_input.c`, includes the
upstream non-TCP `desktop/post_mortem.c` diagnostics implementation,
and does not define `SNESRECOMP_NET` at all in the offline build (some
upstream code tests the macro's *presence*, not its value). Switch compilation
also omits desktop plugin registration constructors and cannot launch the
Falcon cache-builder helper subprocess; neither is needed for normal SMW
gameplay. The original native wide-scene renderer remains linked in
`libsmw-game-core-aarch64.a`.

```sh
cd ~/Desktop/SMW-Switch/SuperMarioWorldRecomp-Switch
git pull origin switch-port
bash switch-port/build-game-nro.sh "../Super Mario World (USA).sfc"
```

This is still an **experimental full-link attempt**, not verified Switch
hardware gameplay. If `ld` emits new errors, those are meaningful missing
host dependencies that must be resolved before release.

## libnx PIE relocation fix

The final ELF is linked using libnx `switch.specs`, which requests a
position-independent executable with strict read-only relocation checks
(`-pie -z text`). The stock Switch application ABI uses `-fPIE` during
**every** C compilation and the Cortex-A57 target flags. Compiling the
game archives and host with default non-PIE code generated a linker
failure even though all sources compiled:

```
ld: read-only segment has dynamic relocations
```

All three scripts now use
`-march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE`.
Because PIE changes code generation, **old archives must be rebuilt**:

```sh
cd ~/Desktop/SMW-Switch/SuperMarioWorldRecomp-Switch
git pull origin switch-port
bash switch-port/build-game-nro.sh "../Super Mario World (USA).sfc"
```

This addresses the mismatch with libnx's required linker model; a
successful final link and Switch boot still require verification on the
actual devkitA64 toolchain and console.
