#include "../mylibc/mylibc.h"

void main()
{
  *LEDS = 1;

  set_draw_buffer(1);

  //*LEDS = 2;

  {

    volatile unsigned char *ptr = (unsigned char *)0x3000000;

    for (int i=0;i<256;i++) {
      *(ptr++) = i;
    }

  //*LEDS = 3;

    //ptr = 0;
    //for (int i=0;i<256;i++) {
    //  *LEDS = *(ptr++);
    //}    
    
    ptr = (unsigned char *)0x3000000;
    set_cursor(0,0);
  
  //*LEDS = 4;
    
    for (int i=0;i<256;i++) {
      //*LEDS = 170;
      unsigned char by = *(ptr++);
      //*LEDS = by;
      putchar("0123456789ABCDEF"[(by >> 4)&15]);
      putchar("0123456789ABCDEF"[(by >> 0)&15]);
      putchar(' ');
      if ((i&15) == 15) { printf("\n"); }
    }
  
    //*LEDS = 7;
  
  }

  while (1)  {}

}
