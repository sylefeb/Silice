#pragma once

extern unsigned char* const FRAMEBUFFER;

typedef unsigned int size_t;

int    putchar(int c);
int    puts(const char* s);
int    printf(const char *fmt,...);
void*  memcpy(void *dest, const void *src, size_t n); 
int    strcmp(const char *p1, const char *p2);
long   cpuid();
long   insn();
long   time();