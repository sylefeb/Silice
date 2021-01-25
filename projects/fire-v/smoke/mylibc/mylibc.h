#pragma once

// special addresses
extern volatile unsigned char* const LEDS;
extern volatile unsigned char* const FRAMEBUFFER;
extern volatile unsigned int*  const SDCARD;
extern volatile unsigned int*  const PALETTE;
extern volatile unsigned int*  const TRIANGLE;
//extern volatile unsigned char* const AUDIO;
//extern volatile unsigned char* const DATA;

typedef unsigned int size_t;

// printf and co.
void   set_cursor(int x,int y);
int    putchar(int c);
int    puts(const char* s);
int    printf(const char *fmt,...);

// memory and strings
void*  memcpy(void *dest, const void *src, size_t n); 
int    strcmp(const char *p1, const char *p2);

// user data (goes through CPU)
long   userdata();

// time
long   insn();
long   time();
void   pause(int cycles);

// framebuffer
extern char fbuffer;
void   swap_buffers(char wait_vsynch);
void   set_draw_buffer(char buffer);
char   get_draw_buffer();

// SDCARD
#include "sdcard.h"
// Flame (GPU)
#include "flame.h"
