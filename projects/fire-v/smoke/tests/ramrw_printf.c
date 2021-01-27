#include "../mylibc/mylibc.h"

// #define ADDR 0x50000
#define ADDR 0x08000

void main()
{
  set_draw_buffer(1);

  volatile unsigned char *ptr = (unsigned char *)ADDR;

  for (int i=0;i<256;i++) {
    *(ptr++) = i;
  }

  ptr = (unsigned char *)ADDR;
  set_cursor(1,0);

  for (int i=0;i<256;i++) {
    unsigned char by = *(ptr++);
    putchar("0123456789ABCDEF"[(by >> 4)&15]);
    putchar("0123456789ABCDEF"[(by >> 0)&15]);
    putchar(' ');
    if ((i&15) == 15) { printf("\n"); }
  }

}
