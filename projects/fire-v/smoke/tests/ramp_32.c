// MIT license, see LICENSE_MIT in Silice repo root

unsigned char* const FRAMEBUFFER = (unsigned char*)0x4000000;

void main() 
{

  unsigned int offset = 0;

  while (1) {
  
    for (unsigned int j = 0 ; j < 200 ; j++) {
      for (unsigned int i = 0 ; i < 320 ; i+=4) {
        *(unsigned int*)(FRAMEBUFFER + i + (j << 9)) =
              ((offset+i+0)&255)
            | ((offset+i+1)&255)<<8
            | ((offset+i+2)&255)<<16
            | ((offset+i+3)&255)<<24
            ;
      }
    }
    ++offset;
  
  }

}
