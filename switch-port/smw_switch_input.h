#ifndef SMW_SWITCH_INPUT_H
#define SMW_SWITCH_INPUT_H
#include <stdint.h>
typedef struct SmwSwitchPad {
  uint16_t snes;  /* SNES B,Y,Select,Start,Up,Down,Left,Right,A,X,L,R bit order */
  int connected;
} SmwSwitchPad;
enum { SMW_SNES_B=1u<<0, SMW_SNES_Y=1u<<1, SMW_SNES_SELECT=1u<<2,
       SMW_SNES_START=1u<<3, SMW_SNES_UP=1u<<4, SMW_SNES_DOWN=1u<<5,
       SMW_SNES_LEFT=1u<<6, SMW_SNES_RIGHT=1u<<7, SMW_SNES_A=1u<<8,
       SMW_SNES_X=1u<<9, SMW_SNES_L=1u<<10, SMW_SNES_R=1u<<11 };
int smw_switch_input_init(void);
SmwSwitchPad smw_switch_input_poll(void);
void smw_switch_input_exit(void);
#endif
