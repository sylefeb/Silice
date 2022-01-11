#define FAT_PRINTF_NOINC_STDIO

#include "fat_io_lib/src/fat_access.c"
#include "fat_io_lib/src/fat_cache.c"
#include "fat_io_lib/src/fat_filelib.c"
#include "fat_io_lib/src/fat_format.c"
#include "fat_io_lib/src/fat_misc.c"
#include "fat_io_lib/src/fat_string.c"
#include "fat_io_lib/src/fat_table.c"
#include "fat_io_lib/src/fat_write.c"

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
  while (*str) {++l;}
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
