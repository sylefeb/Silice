#include "../spiflash.c"

volatile int* const LEDS     = (int*)0x2004;

void main()
{
  spiflash_init();

  // copy to the start of the memory segment
  unsigned char *code = (unsigned char *)0x0000004;
  spiflash_copy(0x100000/*1MB offset*/,code,65536/*SPRAM size*/);
  
  // jump!
  *LEDS = 30; 
  asm volatile ("li t0,4; jalr x0,0(t0);");

  *LEDS = 1;
   while (1) { }

}
