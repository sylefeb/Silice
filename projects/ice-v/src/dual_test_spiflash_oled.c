#include "oled.h"
#include "spiflash.c"

inline unsigned int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles&1;
}

void main_oled_spiflash()
{

  oled_init();
  oled_fullscreen();

  spiflash_init();

  while (1) {

    *LEDS	 = 30;
    spiflash_read_begin(0);	
    for (register int v=0;v<128;v++) {
      for (register int u=0;u<128;u++) {
        unsigned char r = spiflash_read_next();
        unsigned char g = spiflash_read_next();
        unsigned char b = spiflash_read_next();
        oled_pix(r,g,b);
        WAIT;
      }
    }	
    spiflash_read_end();
    *LEDS	 = 1;

  }

}

void main_nop()
{

  while (1) { }

}

void main() 
{

  if (cpu_id() == 0) {

    main_oled_spiflash();

  } else {

    main_nop();

  }

  
	
}
