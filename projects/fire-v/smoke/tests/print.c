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
