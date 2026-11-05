#ifndef SMW_RECOMP_LIBNX_SWITCH_IMPL_H
#define SMW_RECOMP_LIBNX_SWITCH_IMPL_H
#ifdef __SWITCH__
#include <switch.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

/* Mount the SD card and establish a single writable game directory.
 * The existing recomp code uses relative saves/, rom.cfg and config.ini.
 * Keeping cwd here allows its normal SRAM loader/writer to operate without
 * introducing a second, incompatible save format. */
static inline void SwitchImpl_Init(void) {
  if (R_FAILED(fsdevMountSdmc())) {
    fprintf(stderr, "[SMW Switch] SD card mount failed\n");
    return;
  }
  mkdir("sdmc:/switch", 0777);
  mkdir("sdmc:/switch/smw-recomp", 0777);
  if (chdir("sdmc:/switch/smw-recomp") != 0)
    fprintf(stderr, "[SMW Switch] Could not enter save directory\n");
}
static inline void SwitchImpl_Exit(void) {
  fflush(NULL);
  fsdevUnmountAll();
}
#endif
#endif
