#include "../spiflash.c"

#include "../config.h"

static inline int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles&1;
}


void main()
{
  *LEDS = 31;

  if (cpu_id() == 1) {

    spiflash_init();

    // copy to the start of the memory segment
    unsigned char *code = (unsigned char *)0x0000004;
    spiflash_copy(0x100000/*1MB offset*/,code,65532/*SPRAM size*/);
    
    // jump!
    *LEDS = 30;
    asm volatile ("li t0,4; jalr x0,0(t0);");

    *LEDS = 1;
    while (1) { }

  } else {
		
		while (1) { }
		
	}
}
