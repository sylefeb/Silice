volatile unsigned char* const LEDS        = (unsigned char*)0x90000000;
volatile unsigned int*  const SDCARD      = (unsigned int* )0x90000008;

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

#include "../mylibc/sdcard.c"

void main()
{
  *LEDS=128;
  sdcard_init();
  *LEDS=170;
  // copy to the start of the fast-memory segment (BRAM cache)  
  unsigned char *code = (unsigned char *)0x2000000;
  // 58 sectors so that we do not override the boot sector itself!
  // (assumes a 32768 bytes BRAM, boot sectors is ~3064 bytes, 58 = (32768-3064)/512)
  for (int sector=0;sector<58;sector ++) {
    *LEDS=sector;
    code = sdcard_copy_sector(sector,code);
  }
  *LEDS=0;
  asm volatile ("lui t0,0x2000; jalr x0,0(t0);");
  *LEDS=255;
}
