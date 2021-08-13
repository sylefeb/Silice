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
    // l = l + 1;
    
    *LEDS = l;
    
    // for (i=0;i<512;i++) { }
  }
  
}
