// @sylefeb 2020
// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

#include "../mylibc/mylibc.h"

void main()
{

  if (cpuid()) {
    printf("\n\n");
  }
  printf("Hello how are you? (cpu ID:%d)",cpuid());

}
