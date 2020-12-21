/*
SL 2012-12-21

A few custom function (character on screen, etc.).

The rest is hastily composed from a variety of sources (referenced in code) to get something up and running

*/

#include "mylibc.h"
#include "font.h"

unsigned char* const FRAMEBUFFER = (unsigned char*)0x4000000;

int cursor_x = 0x00000001;
int cursor_y = 0x00000002;

int    putchar(int c)
{
  for (int j=0;j<8;j++) {
    for (int i=0;i<8;i++) {
      *(FRAMEBUFFER + (cursor_x + (cursor_y<<9)) + i + (j<<9) ) 
        = (font8x8_basic[c][j] & (1<<i)) ? 63 : 0;
    }
  }
  
  cursor_x += 9;
  if (cursor_x > 320) {
    cursor_x = 0;
    cursor_y += 9;
    if (cursor_y > 200) {
      cursor_y = 0;
    }
  }
  
}

int    puts(const char* s) {}
void*  memcpy(void *dest, const void *src, size_t n) { return 0; }
int    strcmp(const char *p1, const char *p2) { return 0; }

/*
==========================================
         Third party code
==========================================
*/

#include <stdarg.h>

// from https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/FIRMWARE/LIBFEMTOC/printf.c
int    printf(const char *fmt,...) 
{   

  while (*fmt) {
     putchar(*fmt);
     ++fmt;
  }

  //va_list ap;
  //for(va_start(ap, fmt);*fmt;fmt++) {
    /*if(*fmt=='%') {
      fmt++;
      if(*fmt=='s')      print_string(va_arg(ap,char *));
      else if(*fmt=='x') print_hex(va_arg(ap,int));
      else if(*fmt=='d') print_dec(va_arg(ap,int));
      else if(*fmt=='c') putchar(va_arg(ap,int));	   
      else putchar(*fmt);
    } else {*/
  //    putchar(*fmt);
    //}
  //}
  //va_end(ap);
}

#if 0

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

  while (a)
    {
      if (a & 1)
	r += b;
      a >>= 1;
      b <<= 1;
    }
  return r;
}

// modified from https://raw.githubusercontent.com/gcc-mirror/gcc/master/libgcc/config/epiphany/divsi3.c

/* Generic signed 32 bit division implementation.
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

typedef union { unsigned int i; } fu;

/* Although the semantics of the function ask for signed / unsigned inputs,
   for the actual implementation we use unsigned numbers.  */
unsigned int 
__divsi3 (unsigned int a, unsigned int b);

unsigned int
__divsi3 (unsigned int a, unsigned int b)
{
  unsigned int sign = (int) (a ^ b) >> 31;
  unsigned int d, t, s0, s1, s2, r0, r1;
  fu u0, u1, u2, u1b, u2b;

  a = abs (a);
  b = abs (b);

  if (b > a)
    return 0;

  /* Compute difference in number of bits in S0.  */
  u0.i = 0x40000000;
  u1b.i = u2b.i = u0.i;
  u1.i = a;
  u2.i = b;
  u1.i = a | u0.i;
  t = 0x4b800000 | ((a >> 23) & 0xffff);
  if (a >> 23)
    {
      u1.i = t;
      u1b.i = 0x4b800000;
    }
  u2.i = b | u0.i;
  t = 0x4b800000 | ((b >> 23) & 0xffff);
  if (b >> 23)
    {
      u2.i = t;
      u2b.i = 0x4b800000;
    }
  s1 = u1.i >> 23;
  s2 = u2.i >> 23;
  s0 = s1 - s2;

  b <<= s0;
  d = b - 1;

  r0 = 1 << s0;
  r1 = 0;
  t = a - b;
  if (t <= a)
    {
      a = t;
      r1 = r0;
    }

#define STEP(n) case n: a += a; t = a - d; if (t <= a) a = t;
  switch (s0)
    {
    STEP (31)
    STEP (30)
    STEP (29)
    STEP (28)
    STEP (27)
    STEP (26)
    STEP (25)
    STEP (24)
    STEP (23)
    STEP (22)
    STEP (21)
    STEP (20)
    STEP (19)
    STEP (18)
    STEP (17)
    STEP (16)
    STEP (15)
    STEP (14)
    STEP (13)
    STEP (12)
    STEP (11)
    STEP (10)
    STEP (9)
    STEP (8)
    STEP (7)
    STEP (6)
    STEP (5)
    STEP (4)
    STEP (3)
    STEP (2)
    STEP (1)
    case 0: ;
    }
  r0 = r1 | (r0-1 & a);
  return (r0 ^ sign) - sign;
}


/* Generic signed 32 bit modulo implementation.
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

unsigned int __modsi3 (unsigned int a, unsigned int b);

unsigned int
__modsi3 (unsigned int a, unsigned int b)
{
  unsigned int sign = (int) a >> 31;
  unsigned int d, t, s0, s1, s2, r0, r1;
  fu u0, u1, u2, u1b, u2b;

  a = abs (a);
  b = abs (b);

  if (b > a)
    goto ret_a;

  /* Compute difference in number of bits in S0.  */
  u0.i = 0x40000000;
  u1b.i = u2b.i = u0.i;
  u1.i = a;
  u2.i = b;
  u1.i = a | u0.i;
  t = 0x4b800000 | ((a >> 23) & 0xffff);
  if (a >> 23)
    {
      u1.i = t;
      u1b.i = 0x4b800000;
    }
  u2.i = b | u0.i;
  t = 0x4b800000 | ((b >> 23) & 0xffff);
  if (b >> 23)
    {
      u2.i = t;
      u2b.i = 0x4b800000;
    }
  s1 = u1.i >> 23;
  s2 = u2.i >> 23;
  s0 = s1 - s2;

#define STEP(n) case n: d = b << n; t = a - d; if (t <= a) a = t;
  switch (s0)
    {
    STEP (31)
    STEP (30)
    STEP (29)
    STEP (28)
    STEP (27)
    STEP (26)
    STEP (25)
    STEP (24)
    STEP (23)
    STEP (22)
    STEP (21)
    STEP (20)
    STEP (19)
    STEP (18)
    STEP (17)
    STEP (16)
    STEP (15)
    STEP (14)
    STEP (13)
    STEP (12)
    STEP (11)
    STEP (10)
    STEP (9)
    STEP (8)
    STEP (7)
    STEP (6)
    STEP (5)
    STEP (4)
    STEP (3)
    STEP (2)
    STEP (1)
    STEP (0)
    }
 ret_a:
  return (a ^ sign) - sign;
}

#endif