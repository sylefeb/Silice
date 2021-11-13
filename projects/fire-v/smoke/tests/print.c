// @sylefeb 2020
// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

#include "../mylibc/mylibc.h"

void main()
{
  fbuffer = 1;
  set_cursor(7,0);
  unsigned char by = 0xAB;
  for (int i = 0; i < 4 ; i++) {
    putchar("0123456789ABCDEF"[(by >> 4)&15]);
    putchar("0123456789ABCDEF"[(by >> 0)&15]);
    putchar(' ');
  }
}
