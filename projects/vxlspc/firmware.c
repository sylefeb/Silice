#include "../fire-v/smoke/mylibc/mylibc.h"

void main()
{
  
  // copy data into SPRAM
  spiflash_init();
  spiflash_read_begin(0x100000/*1MB offset*/);
  for (int i=0;i<16384;++i) {
    int vl = spiflash_read_next();
    int vh = spiflash_read_next();
    *(TRIANGLE) = ((0<<30) | (i<<16) | (vh<<8) | vl);
    //              ^ SPRAM 0
    // ^^^^^^^ name inherited from fire-v + flame, but this is writting to SPRAM maps 0/1
  }
  spiflash_read_end();

  //spiflash_copy(0x100000/*1MB offset*/,code,16/*SPRAM size*/);

  while (1) {  
    
    // wait for vblank
    while ((userdata()&2) == 0) {  }
    
    // swap buffers
    *(LEDS+4) = 1;
    while ((userdata()&2) == 2) {  }
    
  }
  
}
