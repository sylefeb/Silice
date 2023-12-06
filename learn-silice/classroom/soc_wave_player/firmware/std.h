// @sylefeb 2022
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#pragma once

#include <stddef.h>

// read cycle counter
static inline unsigned int rdcycle()
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

// pauses for a number of cycles
static inline void pause(int ncycles)
{
  unsigned int start = rdcycle();
  while ( rdcycle() - start < ncycles ) { }
}

// UART

void uart_putchar(int c);

// standard C library implementations

void  *memset(void *ptr,int val,size_t sz);
void  *memcpy(void *dst,const void *src,size_t sz);
size_t strlen(const char *str);
int    strncmp(const char * str1,const char * str2,size_t sz);
char  *strncpy(char *dst,const char *src,size_t num);
char  *strcpy(char *dst, const char *src);
char  *strcat(char *dest, const char *src);
