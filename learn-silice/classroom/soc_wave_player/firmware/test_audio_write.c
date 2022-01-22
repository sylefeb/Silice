// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#include "config.h"
#include "std.h"
#include "oled.h"
#include "display.h"
#include "printf.h"

void main()
{
  for (int i = 0; i < 2; ++i) {
    int *addr = (int*)(*AUDIO);
    unsigned char *bdst = (unsigned char*)addr;
    for (int i=0;i<512;++i) {
      *(bdst++) = i;
    }
    // wait for buffer swap
    while (addr == (int*)(*AUDIO)) {  }
  }
}
