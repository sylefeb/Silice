// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2020
// https://github.com/sylefeb/Silice

#include "../mylibc/mylibc.h"

void main()
{

  int px =  11;
  int py =  27;
  int pz = -13;

  *(TRIANGLE+11) = 1; // reinit write address
  *(TRIANGLE+12) = (px&1023) | ((py&1023) << 10) | ((pz&1023) << 20);
  px = 0; py = 0; pz = 0;
  *(TRIANGLE+12) = (px&1023) | ((py&1023) << 10) | ((pz&1023) << 20);

  // print data from bram segment
  unsigned int *ptr = (unsigned int *)0x10000;

  fbuffer = 1;

  for (int i = 0; i < 2 ; i++) {
    int by = *(ptr++);
    putchar("0123456789ABCDEF"[(by >>28)&15]);
    putchar("0123456789ABCDEF"[(by >>24)&15]);
    putchar("0123456789ABCDEF"[(by >>20)&15]);
    putchar("0123456789ABCDEF"[(by >>16)&15]);
    putchar("0123456789ABCDEF"[(by >>12)&15]);
    putchar("0123456789ABCDEF"[(by >> 8)&15]);
    putchar("0123456789ABCDEF"[(by >> 4)&15]);
    putchar("0123456789ABCDEF"[(by >> 0)&15]);
    if ((i&7) == 7) {
      putchar('\n');
    } else {
      putchar(' ');
    }
  }

}
