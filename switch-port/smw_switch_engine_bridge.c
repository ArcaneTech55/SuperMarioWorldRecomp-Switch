/* Game-facing adaptive widescreen surface adapter.
 * This translation unit is deliberately NOT in the diagnostic Makefile:
 * it must link with the complete snesrecomp guest and host game runtime.
 */
#include "smw_switch_engine_bridge.h"
#include "../src/smw_renderer.h"

/* Existing desktop code implements the guest PPU pass here. Linking this
 * requires the generated 65816 program, snesrecomp runner and game state. */
extern void RtlDrawPpuFrame(uint8_t *pixels, size_t pitch, uint32_t flags);

/* Do not replace the upstream adaptive renderer with an SDL stretch. The
 * viewport below is the 342x224 logical frame described in its docs. */
int smw_switch_engine_enable_widescreen(void) {
  g_smw_video.enabled = true;
  g_smw_video.adaptive_spawns = true;
  g_smw_video.aspect = 16.0 / 9.0;
  g_smw_viewport.width = SMW_RECOMP_WIDE_W;
  g_smw_viewport.extra = (SMW_RECOMP_WIDE_W - 256) / 2;
  g_smw_viewport.aspect = 16.0 / 9.0;
  return 1;
}

int smw_switch_engine_draw(SmwSwitchEngineFrame frame, uint32_t flags) {
  if (!frame.pixels || frame.pitch_bytes < SMW_RECOMP_WIDE_W * sizeof(uint32_t))
    return 0;
  if (!g_smw_video.enabled || g_smw_viewport.width != SMW_RECOMP_WIDE_W)
    return 0;
  RtlDrawPpuFrame((uint8_t *)frame.pixels, frame.pitch_bytes, flags);
  return 1;
}
