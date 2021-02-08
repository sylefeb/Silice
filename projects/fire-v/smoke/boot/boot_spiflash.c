volatile unsigned char* const LEDS     = (unsigned char*)0x90000000;
volatile unsigned int*  const SPIFLASH = (unsigned int* )0x90000008;

long time() 
{
  int cycles;
  asm volatile ("rdcycle %0" : "=r"(cycles));
  return cycles;
}

void pause(int cycles)
{ 
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

#include "../mylibc/spiflash.c"

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
