#ifndef SMW_SWITCH_SAVE_H
#define SMW_SWITCH_SAVE_H
#include <stddef.h>
/* Data is kept external to the homebrew executable on the SD card. */
int smw_switch_save_write(const char *path, const void *bytes, size_t size);
int smw_switch_save_read(const char *path, void *bytes, size_t size);
#endif
