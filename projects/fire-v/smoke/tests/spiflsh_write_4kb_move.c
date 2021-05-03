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

void spiflash_copy4KB(int src,int dst)
{
  // erase destination
  spiflash_busy_wait();
  spiflash_erase4KB(dst);
  // copy from src to dst
  for (int n = 0; n < 16 ; n++) { // 16 * 256 = 4KB
    // read 256 bytes
    unsigned char buf[256];
    spiflash_busy_wait();
    spiflash_copy(src,buf,256);
    // write 256 bytes
    spiflash_busy_wait();
    spiflash_write_begin(dst);
    for (int i = 0; i < 256 ; i++) {
      spiflash_write_next(buf[i]);
    }
    spiflash_write_end();
    src = src + 256;
    dst = dst + 256;
  }
}

void main()
{
  spiflash_init();

  *LEDS = 31;
  
  spiflash_copy4KB(0x000000,0x100000);
  spiflash_copy4KB(0x100000,0x000000); 
  
  *LEDS = 0;
}
