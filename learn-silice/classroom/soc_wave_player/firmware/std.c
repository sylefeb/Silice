#include <stddef.h>

#include "config.h"
#include "std.h"

void uart_putchar(int c)
{
  *UART = c;
  pause(10000);
}

// slow implementation, just because we need it
void *memset(void *ptr,int val,size_t sz)
{
  unsigned char *bptr = (unsigned char*)ptr;
  for (int i=0;i<sz;++i) {
    *(bptr++) = val;
  }
  return ptr;
}

// slow implementation, just because we need it
void *memcpy(void *dst,const void *src,size_t sz)
{
  unsigned char *bdst = (unsigned char*)dst;
  unsigned char *bsrc = (unsigned char*)src;
  for (int i=0;i<sz;++i) {
    *(bdst++) = *(bsrc++);
  }
  return dst;
}

size_t strlen(const char *str)
{
  size_t l=0;
  while (*(str++)) {++l;}
  return l;
}

int strncmp(const char * str1,const char * str2,size_t sz)
{
  size_t l=0;
  for (int i=0;i<sz;++i) {
    if ((unsigned char)(*str1) < (unsigned char)(*str2)) {
      return -1;
    } else if ((unsigned char)(*str1) > (unsigned char)(*str2)) {
      return  1;
    }
    ++str1; ++str2;
  }
  return 0;
}

char *strncpy(char *dst,const char *src,size_t num)
{
  char *dst_start = dst;
  while (num != 0) {
    if (*src) {
      *dst = *src;
    } else {
      *dst = '\0';
    }
    ++dst; ++src; --num;
  }
  return dst_start;
}

char *strcpy(char *dst, const char *src)
{
  while (*src) {
    *dst++ = *src++;
  }
  *dst = '\0';
  return dst;
}

char *strcat(char *dest, const char *src)
{
  char *rdest = dest;
  while (*dest)                   { dest++; }
  while ((*dest++ = *src++) != 0) { }
  return rdest;
}
