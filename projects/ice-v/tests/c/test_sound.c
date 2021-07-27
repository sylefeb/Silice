inline long time() 
{
   int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

void main() 
{
  volatile int* const LEDS  = (int*)0x2004;
  volatile int* const SOUND = (int*)0x2020;
  volatile int i = 0;

  int s   = -2048;
  int dir = 64;

  int cy_last = time();

  while (1) {

    int cy = time();
    if (cy > cy_last + 1407) {
      *SOUND  = s;
      cy_last = cy;
      s += dir;
      if (s > 2048 || s < -2048) {
        dir = -dir;
      }
    }
    
  }
  
}
