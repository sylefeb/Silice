#include "../mylibc/mylibc.h"

void main() 
{
  unsigned char count = 0;
  while (1) {
    (*AUDIO) = count++;
  }

}
