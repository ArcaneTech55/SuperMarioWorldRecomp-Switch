#ifndef SMW_SWITCH_VIDEO_H
#define SMW_SWITCH_VIDEO_H

#include <stdbool.h>
#include <stdint.h>

/* The adaptive host renderer produces 342x224 native pixels at 16:9,
 * accounting for the SNES 7:6 pixel aspect ratio. Feed the EXPANDED frame,
 * not the original 256x224 image, to this presenter. */
enum { SMW_SWITCH_WIDE_WIDTH = 342, SMW_SWITCH_WIDE_HEIGHT = 224 };

typedef struct SmwSwitchVideo SmwSwitchVideo;
typedef struct SmwSwitchRect { int x, y, w, h; } SmwSwitchRect;

SmwSwitchRect smw_switch_fit_16_9(int screen_w, int screen_h);
SmwSwitchVideo *smw_switch_video_create(void);
void smw_switch_video_destroy(SmwSwitchVideo *video);
bool smw_switch_video_present(SmwSwitchVideo *video,
                              const uint32_t *argb, int width,
                              int height, int pitch_bytes);
#endif
