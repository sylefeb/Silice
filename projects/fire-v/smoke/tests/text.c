#include "../mylibc/mylibc.h"

void main() 
{

  if (cpuid()) {
    printf("\n\n");
  }
  printf("Hello how are you? (cpu ID:%d)",cpuid());

}
