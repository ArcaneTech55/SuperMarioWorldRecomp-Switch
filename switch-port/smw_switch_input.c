#include "smw_switch_input.h"
#ifdef __SWITCH__
#include <switch.h>
static PadState pad;
int smw_switch_input_init(void) {
  padConfigureInput(1, HidNpadStyleSet_NpadStandard);
  padInitializeDefault(&pad);
  return 1;
}
SmwSwitchPad smw_switch_input_poll(void) {
  padUpdate(&pad);
  uint64_t held = padGetButtons(&pad);
  uint16_t snes = 0;
  if (held & HidNpadButton_B) snes |= SMW_SNES_B;
  if (held & HidNpadButton_Y) snes |= SMW_SNES_Y;
  if (held & HidNpadButton_Minus) snes |= SMW_SNES_SELECT;
  if (held & HidNpadButton_Plus) snes |= SMW_SNES_START;
  if (held & (HidNpadButton_Up | HidNpadButton_StickLUp)) snes |= SMW_SNES_UP;
  if (held & (HidNpadButton_Down | HidNpadButton_StickLDown)) snes |= SMW_SNES_DOWN;
  if (held & (HidNpadButton_Left | HidNpadButton_StickLLeft)) snes |= SMW_SNES_LEFT;
  if (held & (HidNpadButton_Right | HidNpadButton_StickLRight)) snes |= SMW_SNES_RIGHT;
  if (held & HidNpadButton_A) snes |= SMW_SNES_A;
  if (held & HidNpadButton_X) snes |= SMW_SNES_X;
  if (held & HidNpadButton_L) snes |= SMW_SNES_L;
  if (held & HidNpadButton_R) snes |= SMW_SNES_R;
  return (SmwSwitchPad){snes, padIsConnected(&pad)};
}
void smw_switch_input_exit(void) {}
#else
int smw_switch_input_init(void) { return 0; }
SmwSwitchPad smw_switch_input_poll(void) { return (SmwSwitchPad){0,0}; }
void smw_switch_input_exit(void) {}
#endif
