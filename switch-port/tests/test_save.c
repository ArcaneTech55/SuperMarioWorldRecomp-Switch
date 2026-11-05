#include "../smw_switch_save.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>
int main(void) {
  const char *path = "/tmp/smw-switch-save-test.bin";
  unsigned char a[] = {1, 2, 3, 4, 5}, b[5] = {0};
  remove(path);
  assert(!smw_switch_save_read(path, b, sizeof b));
  assert(smw_switch_save_write(path, a, sizeof a));
  assert(smw_switch_save_read(path, b, sizeof b));
  assert(!memcmp(a,b,sizeof a));
  assert(!smw_switch_save_read(path, b, sizeof b-1));
  remove(path);
  puts("SMW storage roundtrip tests: PASS");
}
