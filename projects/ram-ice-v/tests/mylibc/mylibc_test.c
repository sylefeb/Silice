#include "mylibc.h"

void print_dec(int val);

void main()
{
/*  
    for (int j = 0 ; j < 200 ; j++) {
      for (int i = 0 ; i < 320 ; i++) {
        *(FRAMEBUFFER + i + (j << 9)) = (unsigned char)(i);
      }
    }
*/
  printf("Hello world\n\n");
 
  while (1) {
    printf("time = %d -- insn = %d\n",time(),insn());
  }

// asm("unimp\n");

}
