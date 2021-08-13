#include "oled.h"

#include "spiflash.c"

void main() 
{
/*
int v = 0;
v = *SPIFLASH;
*LEDS = v;
*/
  oled_init();
  oled_fullscreen();
	
*LEDS	 = 31;
	spiflash_init();
*LEDS	 = 1;
  spiflash_read_begin(0);	
*LEDS	 = 2;
  spiflash_read_next();

/*
	int b = 0;
  while (1) {
    b+=7;
    oled_clear(b);
  } 
*/

	spiflash_read_begin(0);	
  for (int v=0;v<128;v++) {
    for (int u=0;u<128;u++) {
			unsigned char r = spiflash_read_next();
			unsigned char g = spiflash_read_next();
			unsigned char b = spiflash_read_next();
			oled_pix(r,g,b);
	  }
	}	
	spiflash_read_end();

*LEDS	 = 16;
	
	while (1) { }
	
}
