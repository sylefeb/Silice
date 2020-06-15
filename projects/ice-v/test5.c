void main() 
{
  int *led = (int*)0x400;
  int i = 0;

  int l = 1;
  while (1) {
  
    l <<= 1;
    if (l > 8) {
      l = 1;
    }
    *led = (l | 16);
    
    for (i=0;i<65535;i++) { }
  
  }

}
