// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice
// @sylefeb 2021

volatile unsigned int* const UART     = (unsigned int*)0x90000000;
volatile unsigned int* const SPIFLASH = (unsigned int*)0x90000008;

long time()
{
  int cycles;
  asm volatile ("rdcycle %0" : "=r"(cycles));
  return cycles;
}

void pause(int cycles)
{
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

void f_putchar(int c)
{
  (*UART) = c | 0xff000000;
  pause(16384);
}

void print_string(const char* s)
{
   for (const char* p = s; *p; ++p) {
      f_putchar(*p);
   }
}

void print_hex_digits(unsigned int val, int nbdigits)
{
   for (int i = (4*nbdigits)-4; i >= 0; i -= 4) {
      f_putchar("0123456789ABCDEF"[(val >> i) & 15]);
   }
}

void print_hex(unsigned int val)
{
   print_hex_digits(val, 8);
}

#include <stdarg.h>

int printf(const char *fmt,...)
{
  va_list ap;
  for (va_start(ap, fmt);*fmt;fmt++) {
    if (*fmt=='%') {
      fmt++;
      if (*fmt=='s')      print_string(va_arg(ap,char *));
      else if (*fmt=='x') print_hex(va_arg(ap,int));
      // else if (*fmt=='d') print_dec(va_arg(ap,int));
      else if (*fmt=='c') f_putchar(va_arg(ap,int));
      else                f_putchar(*fmt);
    } else {
      f_putchar(*fmt);
    }
  }
  va_end(ap);
}

#include "../fire-v/smoke/mylibc/spiflash.c"

typedef void (*t_patch_func)(int,unsigned char*);

void main()
{
  spiflash_init();
  // read n first bytes from SPI and send them over UART
  const int N = 256;
  while (1) {
    printf("Hello world\n");
    spiflash_read_begin( /*0*/ 2097152 );
    for (int addr=0;addr<N;++addr) {
      unsigned char b = spiflash_read_next();
      printf("byte @%x = %x\n",addr,b);
    }
    spiflash_read_end();
  }
}
