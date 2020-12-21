#pragma once

extern unsigned char* const FRAMEBUFFER;

typedef unsigned int size_t;

//extern void exit(int);
//extern void abort();
int  putchar(int c); //
int  puts(const char* s); //
int  printf(const char *fmt,...); // 

//void*  memset(void *s, int c, size_t n); 
void*  memcpy(void *dest, const void *src, size_t n); //

//char*  strcpy(char *dest, const char *src);
//char*  strncpy(char *dest, const char *src, size_t n);
int    strcmp(const char *p1, const char *p2);
//size_t strlen(const char* p);
