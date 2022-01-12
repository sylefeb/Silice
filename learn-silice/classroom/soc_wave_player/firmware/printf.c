#include "printf.h"

void (*f_putchar)(int);

void print_string(const char* s)
{
   for (const char* p = s; *p; ++p) {
      f_putchar(*p);
   }
}

void print_dec(int val)
{
   char buffer[255];
   char *p = buffer;
   if (val < 0) {
      f_putchar('-');
      print_dec(-val);
      return;
   }
   while (val || p == buffer) {
      int q = val / 10;
      *(p++) = val - q * 10;
      val    = q;
   }
   while (p != buffer) {
      f_putchar('0' + *(--p));
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
      else if (*fmt=='d') print_dec(va_arg(ap,int));
      else if (*fmt=='c') f_putchar(va_arg(ap,int));
      else                f_putchar(*fmt);
    } else {
      f_putchar(*fmt);
    }
  }
  va_end(ap);
}
