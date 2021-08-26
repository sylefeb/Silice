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

  int offs = 0;

  while (1) {

    spiflash_read_begin(offs);	
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
    offs = offs + 128*3;

  }

}

void main_nop()
{

  while (1) { }

}

void main() 
{

  if (cpu_id() == 1) {

    main_oled_spiflash();

  } else {

    main_nop();
    
  }
	
}
