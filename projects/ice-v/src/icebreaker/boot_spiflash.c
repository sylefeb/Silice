#include "../spiflash.c"

void main()
{
  *LEDS = 31;

  spiflash_init();

  // copy to the start of the memory segment
  unsigned char *code = (unsigned char *)0x0000004;
  spiflash_copy(0x100000/*1MB offset*/,code,65532/*SPRAM size*/);
  
  // jump!
  *LEDS = 30;
  asm volatile ("li t0,4; jalr x0,0(t0);");

  *LEDS = 1;
  while (1) { }

}
