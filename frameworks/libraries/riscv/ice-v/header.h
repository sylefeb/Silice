// @sylefeb, MIT license

void *memcpy(void *dst, const void* src, long unsigned int size)
{
  long unsigned int c = size &3;
  long unsigned int w = size>>2;
  int       *w_dst    = (int*)dst;
  const int *w_src    = (const int*)src;
  for (long unsigned int i = 0 ; i < w; ++i) { *(w_dst++) = *(w_src++); }
  char       *c_dst   = (char*)w_dst;
  const char *c_src   = (const char*)w_src;
  for (long unsigned int i = 0 ; i < c; ++i) { *(c_dst++) = *(c_src++); }
}

