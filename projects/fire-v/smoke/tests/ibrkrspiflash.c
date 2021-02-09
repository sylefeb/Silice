#include "../mylibc/mylibc.h"

void main()
{

  *LEDS = 0;

  spiflash_init();
    
  for (int i = 0; i < 16384; i++) {
    unsigned char r = 0;
    spiflash_copy(i,&r,1);
    *LEDS = r;
    pause(1000000);
  }

}
