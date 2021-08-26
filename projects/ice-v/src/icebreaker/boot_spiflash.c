#include "../spiflash.c"
#include "../config.h"

static inline int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles&1;
}

void main_load_code()
{
    *LEDS = 1;
    spiflash_init();
    *LEDS = 2;

    // copy to the start of the memory segment
    unsigned char *code = (unsigned char *)0x0000004;    
    spiflash_copy(256000/*offset*/,code,4096/*SPRAM size*/);
  
    // jump!
    *LEDS = 7;
    asm volatile ("li t0,4; jalr x0,0(t0);");

//    *LEDS = 0;
    while (1) { }
}

void main_nop()
{
  while (1) { }
}


void main()
{

  if (cpu_id() == 0) {

    main_load_code();

  } else {
		
		main_nop();
		
	}
}
