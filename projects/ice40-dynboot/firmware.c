volatile unsigned int* const WARMBOOT = (unsigned int*)0x90000000;
volatile unsigned int* const SPIFLASH = (unsigned int*)0x90000008;

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

#include "../fire-v/smoke/mylibc/spiflash.c"

typedef void (*t_patch_func)(int,unsigned char*);

void spiflash_copy_patch_4KB(int src,int dst,t_patch_func f)
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
    // patch
    f(src,buf);
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
	spiflash_busy_wait();
}

void no_patch(int start_addr,unsigned char *buf) { }

void patch_vector(int start_addr,unsigned char *buf) 
{ 
  if (start_addr == 0) {
    // three bytes per vector (24 bits)
    // reset   at buf[ 9],buf[10],buf[11]
    // image 0 at buf[41],buf[42],buf[43]
    // image 1 at buf[73],buf[74],buf[75]
    // ... (we do not need the others!)
    int current = (buf[73]<<16) + (buf[74]<<8)  + buf[75];
		if (current < (104250 + 104090)) {
			current = current + 104090;
		} else {
			current = 104250;
		}
		buf[73] =  current>>16;
		buf[74] = (current>> 8)&255;
		buf[75] = (current    )&255;
  }
}

void main()
{

  spiflash_init();

  // copy to a free location and patch slot 1 vector
  spiflash_copy_patch_4KB(0x000000,0x100000,patch_vector);
	
  // copy back
  spiflash_copy_patch_4KB(0x100000,0x000000,no_patch); 
	
  // reboot to slot 1  
	while (1) {
		*WARMBOOT = (1<<9) | 1;
	}
}

