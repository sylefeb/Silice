inline int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles>>31;
}

void main() 
{
  volatile int* const LEDS = (int*)0x2004;
  volatile int i = 0;

  *LEDS = 0x0f;
  
  int l = 1;

  while (1) {  
    l <<= 1;
    if (l > 8) {
      l = 1;
    }    
    *LEDS = l;       
    for (i=0;i<655360;i++) { }
  }

}
