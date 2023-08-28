// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2021
// https://github.com/sylefeb/Silice

#include "config.h"
#include "printf.h"

void f_putchar(int c)
{
#ifdef ICEBREAKER_SWIRL
  *LEDS = c;
#else
  *UART = c;
#endif
  for (volatile int i = 0 ; i < 1024 ; ++i ) { }
}

void main()
{
  int n = 0;
  //print_string("hello world");
  // for (int i = 0 ; i < 32 ; ++i) {
  while (1) {
    printf("hello world %d\n",n+=13);
  }
  //printf("hello world %x\n",n++);
  //printf("hello world %x\n",n++);

  //f_putchar('A');
  //f_putchar('B');
  //f_putchar('C');
  *LEDS = 0xffffffff;
}
