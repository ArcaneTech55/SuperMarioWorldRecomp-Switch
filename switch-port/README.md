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
