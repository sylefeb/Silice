/*
SL 2022-10-13

A few custom functions

Hhastily composed from a variety of sources (referenced in code) to get
something up and running

// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

*/

#include "mylibc.h"

volatile int *PUTC    = (volatile int *)0x20000;
volatile int *REINSTR = (volatile int *)0x20000;

int    putchar(int c)
{
  *PUTC = c;
  return c;
}

void *memcpy(void *dest, const void *src, size_t n) {
  const void *end = src + n;
  const unsigned char *bsrc = (const unsigned char *)src;
  while (bsrc != end) {
    *(unsigned char*)dest = *(++bsrc);
  }
  return dest;
}

char *strcpy(char *dst, const char *src) {
  char *tmp = dst;
  while (*src) {
    *dst++ = *src++;
  }
  return dst;
}

int strcmp(const char *p1, const char *p2) {
  while (*p1 && (*p1 == *p2)) {
    p1++; p2++;
  }
  return *(const unsigned char*)p1 - *(const unsigned char*)p2;
}

void pause(int cycles)
{
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

char fbuffer = 0;

void   swap_buffers(char wait_vsynch) {}
void   set_draw_buffer(char buffer) {}
char   get_draw_buffer() { return fbuffer; }


/*
==========================================
         Third party code
==========================================
*/

#include <stdarg.h>

// from https://github.com/cliffordwolf/picorv32/blob/f9b1beb4cfd6b382157b54bc8f38c61d5ae7d785/dhrystone/stdlib.c

inline long time()
{
   int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

inline long insn()
{
   return *REINSTR;
}

inline long userdata()
{
  int id;
  asm volatile ("rdtime %0" : "=r"(id));
  return id;
}

// from https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/FIRMWARE/LIBFEMTOC/printf.c

void print_string(const char* s) {
   for(const char* p = s; *p; ++p) {
      putchar(*p);
   }
}

int puts(const char* s) {
   print_string(s);
   putchar('\n');
   return 1;
}

void print_dec(int val) {
   char buffer[255];
   char *p = buffer;
   if(val < 0) {
      putchar('-');
      print_dec(-val);
      return;
   }
   while (val || p == buffer) {
      *(p++) = val % 10;
      val = val / 10;
   }
   while (p != buffer) {
      putchar('0' + *(--p));
   }
}

void print_hex(unsigned int val) {
   print_hex_digits(val, 8);
}

void print_hex_digits(unsigned int val, int nbdigits) {
   for (int i = (4*nbdigits)-4; i >= 0; i -= 4) {
      putchar("0123456789ABCDEF"[(val >> i) % 16]);
   }
}

int printf(const char *fmt,...)
{
  va_list ap;
  for(va_start(ap, fmt);*fmt;fmt++) {
    if(*fmt=='%') {
      fmt++;
      if(*fmt=='s')      print_string(va_arg(ap,char *));
      else if(*fmt=='x') print_hex(va_arg(ap,int));
      else if(*fmt=='d') print_dec(va_arg(ap,int));
      else if(*fmt=='c') putchar(va_arg(ap,int));
      else putchar(*fmt);
    } else {
      putchar(*fmt);
    }
  }
  va_end(ap);
}

// Quick hack mulsi3

unsigned int __mulsi3 (unsigned int ia, unsigned int ib)
{
  register unsigned int a = ia;
  register unsigned int b = ib;
  register unsigned int r = 0;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  if (!a) return r;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  if (!a) return r;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  if (!a) return r;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  if (!a) return r;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  if (!a) return r;

  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;
  if (a & 1) { r += b; } a >>= 1; b <<= 1;

  return r;
}
