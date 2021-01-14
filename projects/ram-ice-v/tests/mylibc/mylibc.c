/*
SL 2012-12-21

A few custom functions (character on screen, etc.).

The rest is hastily composed from a variety of sources (referenced in code) to get something up and running

*/

#include "mylibc.h"
#include "tama_mini02_font.h"

volatile unsigned char* const LEDS        = (unsigned char*)0x20000000;
volatile unsigned int*  const PALETTE     = (unsigned int* )0x83000000;
// Why 0x83000000 ? We set bit 31 so video_rv32i knows we are using a mapped address, 
// but still write to the last memory bank (0x03000000) where nothing is used.
// The reason is that video_rv32i does not mask addresses and therefore a SDRAM write still
// occurs; we don't want this to end in the framebuffer! 

volatile unsigned char* const FRAMEBUFFER = (unsigned char*)0x40000000;
volatile unsigned char* const AUDIO       = (unsigned char*)0x4C000000;
volatile unsigned char* const DATA        = (unsigned char*)0x42020000;
volatile unsigned int*  const TRIANGLE    = (unsigned char*)0x10000000;

int cursor_x = 0x00000000;
int cursor_y = 0x00000000;

void set_cursor(int x,int y)
{
  cursor_x = x;
  cursor_y = y;  
}

int    putchar(int c)
{
  
  if (c == 10) {
    // clear rest of line
    //for (int j=0;j<8;j++) {
    //  for (int i=cursor_x;i<320;i++) {
    //    *(FRAMEBUFFER + (i + ((cursor_y+j)<<9)) ) = 0;
    //  }
    //}
    // next line
    cursor_x = 0;
    cursor_y += 8;
    if (cursor_y > 200) {
      cursor_y = 0;
    }
    return c;
  }

  if (c >= 32) {
    for (int j=0;j<8;j++) {
      for (int i=0;i<5;i++) {
        *(FRAMEBUFFER + (cursor_x + i + ((cursor_y+j)<<9)) ) 
          = (font[c-32][i] & (1<<j)) ? 255 : 31;
          /*
        // Note: this is only important for the BRAM version  ...
        //       we wait to ensure SDRAM writes are completed ...
        long tm_start = time();
        while (time() - tm_start < 1) { }        
        */
      }
    }
  }
  
  cursor_x += 5;
  if (cursor_x > 320) {
    cursor_x = 0;
    cursor_y += 8;
    if (cursor_y > 200) {
      cursor_y = 0;
    }
  }
  
  return c;
}

void*  memcpy(void *dest, const void *src, size_t n) { 
  const void *end = src + n;
  const unsigned char *bsrc = (const unsigned char *)src;
  while (bsrc != end) {
    *(unsigned char*)dest = *(++bsrc);
  }
  return dest;
}

int strcmp(const char *p1, const char *p2) { 
  while (*p1 && (*p1 == *p2)) {
    p1++; p2++;    
  }
  return *(const unsigned char*)p1 - *(const unsigned char*)p2;
}

/*
==========================================
         Third party code
==========================================
*/

#include <stdarg.h>

// from https://github.com/cliffordwolf/picorv32/blob/f9b1beb4cfd6b382157b54bc8f38c61d5ae7d785/dhrystone/stdlib.c

long time() 
{
   int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

long insn() 
{
   int insns;
   asm volatile ("rdinstret %0" : "=r"(insns));
   return insns;
}

long cpuid() 
{
  // SL: This is non standard, find another way
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

// from https://raw.githubusercontent.com/gcc-mirror/gcc/master/libgcc/config/epiphany/mulsi3.c

/* Generic 32 bit multiply.
   Copyright (C) 2009-2020 Free Software Foundation, Inc.
   Contributed by Embecosm on behalf of Adapteva, Inc.
This file is part of GCC.
This file is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3, or (at your option) any
later version.
This file is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.
Under Section 7 of GPL version 3, you are granted additional
permissions described in the GCC Runtime Library Exception, version
3.1, as published by the Free Software Foundation.
You should have received a copy of the GNU General Public License and
a copy of the GCC Runtime Library Exception along with this program;
see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see
<http://www.gnu.org/licenses/>.  */

unsigned int __mulsi3 (unsigned int a, unsigned int b)
{
  unsigned int r = 0;

  while (a) {
      if (a & 1) {
        r += b;
      }
      a >>= 1;
      b <<= 1;
  }
  return r;
}
