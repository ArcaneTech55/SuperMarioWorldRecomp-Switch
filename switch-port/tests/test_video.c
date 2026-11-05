#include "../smw_switch_video.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
  assert(SMW_SWITCH_WIDE_WIDTH == 342 && SMW_SWITCH_WIDE_HEIGHT == 224);
  SmwSwitchRect r = smw_switch_fit_16_9(1280, 720);
  assert(r.x == 0 && r.y == 0 && r.w == 1280 && r.h == 720);
  r = smw_switch_fit_16_9(800, 600);
  assert(r.x == 0 && r.y == 75 && r.w == 800 && r.h == 450);
  r = smw_switch_fit_16_9(1920, 1080);
  assert(r.w == 1920 && r.h == 1080);
  r = smw_switch_fit_16_9(0, 720);
  assert(r.w == 0 && r.h == 0);
  puts("SMW Switch video geometry tests: PASS");
  return 0;
}
