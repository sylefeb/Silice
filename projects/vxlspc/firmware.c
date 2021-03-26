#include "../fire-v/smoke/mylibc/mylibc.h"

void main()
{
  //spiflash_init();

  //unsigned char *code = (unsigned char *)0x0000004;
  //spiflash_copy(0x100000/*1MB offset*/,code,16/*SPRAM size*/);

  while (1) {  
    
    // wait for vblank
    while ((userdata()&2) == 0) {  }
    
    // swap buffers
    *(LEDS+4) = 1;
    while ((userdata()&2) == 2) {  }
    
  }
  
}
