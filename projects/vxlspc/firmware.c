#include "../fire-v/smoke/mylibc/mylibc.h"

void main()
{
  spiflash_init();

  //unsigned char *code = (unsigned char *)0x0000004;
  //spiflash_copy(0x100000/*1MB offset*/,code,16/*SPRAM size*/);

  while (1) {  
    
    // putchar('0');
    
    // wait for vblank
    while ((userdata()&2) == 0) {  }
    // swap buffers
    *(LEDS+4) = 1;

/*    *LEDS = 0xaa;
    pause(10000000);
    *LEDS = 0x55;
    pause(10000000);    
*/
  }
}
