#include "mylibc.h"

void main()
{
/*  
    for (int j = 0 ; j < 200 ; j++) {
      for (int i = 0 ; i < 320 ; i++) {
        *(FRAMEBUFFER + i + (j << 9)) = (unsigned char)(i);
      }
    }
*/
 printf("Abcdefghijklmnopqrstuvwxyz");
 // printf("ABC");

 asm("unimp\n");

}
