volatile unsigned char* const FRAMEBUFFER = (unsigned char*)0x1000000;

void main() 
{

  int offset = 0;

  while (1) {
  
    volatile unsigned char *ptr = FRAMEBUFFER;
    for (int j = 0 ; j < 64000 ; j++) {
        *(ptr++) = (unsigned char)(offset+j);
    }
  
    ++offset;
  
  }

}
