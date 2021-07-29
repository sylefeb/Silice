inline int cpu_id() 
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles>>31;
}

void main() 
{
  volatile int* const LEDS = (int*)0x2004;

  if (cpu_id()) {  
    while (1) {
      *LEDS = 2;
    }
  } else {
    while (1) {
      *LEDS = 16;
    }  
  }

}
