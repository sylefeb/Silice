#include "mylibc.h"

void main()
{
  /*
  int i = 0;
  while (1) {
    i++;
    printf("i = %d\n",i);
  }
  */
  volatile int *ptr = (volatile int *)0x20000;
  printf("v = %x\n",*ptr);
}
