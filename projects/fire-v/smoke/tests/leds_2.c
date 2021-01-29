//#include "../mylibc/mylibc.h"
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
    int iter = 0;
    while (++iter < 8) {  
      *(volatile unsigned char*)0x90000000 = 0xaa;
      pause(25000000);
      *(volatile unsigned char*)0x90000000 = 0x55;
      pause(25000000);
    }
    for (int i = 0; i < 8 ; i++) {
      *(volatile unsigned char*)0x90000000 = -i;
      pause(10000000);
    }
    for (int i = 0; i < 8 ; i++) {
      *(volatile unsigned char*)0x90000000 = (1<<i);
      pause(50000000);
    }
    for (int i = 0; i < 8 ; i++) {
      *(volatile unsigned char*)0x90000000 = (128>>i);
      pause(50000000);
    }
  }
}
