#ifndef SMW_SWITCH_ENGINE_BRIDGE_H
#define SMW_SWITCH_ENGINE_BRIDGE_H
#include <stdint.h>
#include <stddef.h>
#include "smw_switch_video.h"

/* The bridge is compiled with the real recompilation game target, not with
 * the standalone platform-check NRO. The 342x224 buffer must be supplied
 * to the adaptive renderer, not filled by stretching 256x224 native video. */
enum { SMW_RECOMP_WIDE_W = 342, SMW_RECOMP_WIDE_H = 224 };
typedef struct SmwSwitchEngineFrame {
  uint32_t *pixels;
  size_t pitch_bytes;
} SmwSwitchEngineFrame;

/* Call only after the snesrecomp guest+renderer have been initialized. */
int smw_switch_engine_enable_widescreen(void);
int smw_switch_engine_draw(SmwSwitchEngineFrame frame, uint32_t flags);
/* Draw and present with Switch SDL2 once the game runner is active. */
int smw_switch_engine_render_present(SmwSwitchVideo *video,
                                     SmwSwitchEngineFrame frame,
                                     uint32_t flags);
#endif
