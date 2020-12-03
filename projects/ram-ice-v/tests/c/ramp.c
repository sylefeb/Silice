volatile unsigned char* const FRAMEBUFFER = (unsigned char*)0x1000000;

void main() 
{

  while (1) {
  
    volatile unsigned char *ptr = FRAMEBUFFER;
    for (int j = 0 ; j < 64000 ; j++) {
        *(ptr++) = (unsigned char)j;
    }
  
  }

}
