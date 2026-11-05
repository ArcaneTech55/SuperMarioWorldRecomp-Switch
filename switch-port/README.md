# Super Mario World Recomp: Nintendo Switch port (work in progress)

This branch is dedicated to porting [mstan/SuperMarioWorldRecomp](https://github.com/mstan/SuperMarioWorldRecomp) to the Nintendo Switch, preserving its *actual* adaptive widescreen renderer. Keep upstream PolyForm Noncommercial 1.0.0 license and notices.

## Verified ROM

Use a **local**, original USA ROM named `Super Mario World (USA).sfc`.
Expected SHA-1: `6b47bb75d16514b6a476aa0c73a683a2a4c18765`.
**Do not commit ROMs, ROM-derived assets or dumps to this public fork.**

## Mac setup

```sh
mkdir -p "$HOME/Desktop/SMW-Switch"
cd "$HOME/Desktop/SMW-Switch"
git clone --recursive -b switch-port https://github.com/ArcaneTech55/SuperMarioWorldRecomp-Switch.git
cd SuperMarioWorldRecomp-Switch
git submodule update --init --recursive
bash switch-port/check-mac.sh "../Super Mario World (USA).sfc"
```

Copy your downloaded ROM into `~/Desktop/SMW-Switch/` before running the last command. The ROM is outside the Git repository.

## Implemented

- Independent Switch SDL2 texture presenter receiving an **already expanded** ARGB8888 frame
- 16:9 fit geometry, size/pitch safety guards, streaming texture recreation
- Standalone host video geometry tests and devkitPro/ROM prerequisite script

## Still required before a playable .nro

The upstream game currently targets desktop SDL/OpenGL, CMake OpenGL dependencies, desktop launcher and runtime libraries. The presented texture is **not yet connected** to `SmwRendererDraw`; no libnx input/audio/storage lifecycle, AOT-generated game code integration, or Switch executable target has been completed. Do not label this as a playable Switch build. Running `check-mac.sh` checks prerequisites; **it does not compile an NRO**.

Important: upstream widescreen uses 342x224 *native pixels* at 16:9 (native SNES pixel aspect 7:6), expanded scene/camera/HUD, not a stretched 256x224 image.
