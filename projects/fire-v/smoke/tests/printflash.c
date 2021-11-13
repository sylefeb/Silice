// @sylefeb 2020
// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

#include "../mylibc/mylibc.h"

void main()
{
  fbuffer = 1;

  *LEDS = 0;

  spiflash_init();
  unsigned char tbl[256];
  spiflash_copy(0x100000/*1MB offset*/,tbl,256);

  for (int i = 0; i < 256 ; i++) {
    unsigned char by = tbl[i];
    putchar("0123456789ABCDEF"[(by >> 4)&15]);
    putchar("0123456789ABCDEF"[(by >> 0)&15]);
    if ((i&7) == 7) {
      putchar('\n');
    } else {
      putchar(' ');
    }
  }
}
