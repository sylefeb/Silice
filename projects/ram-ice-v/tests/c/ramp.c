volatile unsigned char* const FRAMEBUFFER = (unsigned char*)0x1000000;

void main() 
{

  while (1) {
  
    volatile unsigned char *ptr = FRAMEBUFFER;
    for (int j = 0 ; j < 200 ; j++) {
      for (int i = 0 ; i < 320 ; i++) {
        *(ptr++) = (unsigned char)j;
      }
    }
  
  }

}
