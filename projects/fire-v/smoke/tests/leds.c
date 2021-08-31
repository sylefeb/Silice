// MIT license, see LICENSE_MIT in Silice repo root

// compile_c.sh smoke/tests/leds.c --nolibc

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

void main() 
{
  while (1) {  
    *(volatile unsigned char*)0x90000000 = 0xaa;
    pause(10000000);
    *(volatile unsigned char*)0x90000000 = 0x55;
    pause(10000000);
  }
}

