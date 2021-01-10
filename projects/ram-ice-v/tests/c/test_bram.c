#include "../mylibc/mylibc.h"

void pause(int cycles)
{ 
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

void main() 
{

  int i = 0;
  while (1) {
    *(FRAMEBUFFER + i) = i++;
    // pause(40);
    if (i > 320<<9) {
      i=0;
    }
    set_cursor(0,0);
    printf("Hello how are you?");

  }

}
