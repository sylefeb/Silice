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
    while (++iter < 64) {  
      *(volatile unsigned char*)0x80000000 = 0xaa;
      pause(10000000);
      *(volatile unsigned char*)0x80000000 = 0x55;
      pause(10000000);
    }
    for (int i = 0; i < 65536 ; i++) {
      *(volatile unsigned char*)0x80000000 = -i;
      pause(10000000);
    }
  }
}
