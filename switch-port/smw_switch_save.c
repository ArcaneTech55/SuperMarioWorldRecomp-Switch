#include "smw_switch_save.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#if defined(_WIN32)
#include <io.h>
#define smw_sync _commit
#else
#include <unistd.h>
#define smw_sync fsync
#endif
/* Writes temporary data, flushes it, then renames. This API alone
 * does not hook up the guest SRAM yet; callers must supply the bytes. */
int smw_switch_save_write(const char *path, const void *bytes, size_t size) {
  if (!path || !bytes || !size || size > 16u*1024u*1024u) return 0;
  size_t len = strlen(path);
  if (len > 1023) return 0;
  char tmp[1030];
  memcpy(tmp, path, len);
  memcpy(tmp + len, ".tmp", 5);
  FILE *f = fopen(tmp, "wb");
  if (!f) return 0;
  int ok = fwrite(bytes, 1, size, f) == size;
  if (ok) ok = fflush(f) == 0;
  if (ok) ok = smw_sync(fileno(f)) == 0;
  if (fclose(f) != 0) ok = 0;
  if (ok && rename(tmp, path) != 0) ok = 0;
  if (!ok) remove(tmp);
  return ok;
}
int smw_switch_save_read(const char *path, void *bytes, size_t size) {
  if (!path || !bytes || !size || size > 16u*1024u*1024u) return 0;
  FILE *f = fopen(path, "rb");
  if (!f) return 0;
  int ok = fread(bytes, 1, size, f) == size && fgetc(f) == EOF && !ferror(f);
  if (fclose(f) != 0) ok = 0;
  return ok;
}
