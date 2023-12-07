
#include "tama_mini02_font.h"
#include "config.h"
#include "oled.h"
#include "display.h"
#include "std.h"

int cursor_x;
int cursor_y;

unsigned char front_color;
unsigned char back_color;

#ifdef HWFBUFFER
#define framebuffer ((volatile unsigned char *)DISPLAY)
#else
unsigned char framebuffer[128*128];
#endif

volatile unsigned char *display_framebuffer()
{
  return framebuffer;
}

void display_set_cursor(int x,int y)
{
  cursor_x = x;
  cursor_y = y;
}

void display_set_front_back_color(unsigned char f,unsigned char b)
{
  front_color = f;
  back_color = b;
}

void display_putchar(int c)
{
  if (c == 10) {
    // next line
    cursor_x = 0;
    cursor_y += 8;
    if (cursor_y >= 128) {
      cursor_y = 0;
    }
    return;
  }
  if (c >= 32) {
    for (int j=0;j<8;j++) {
      for (int i=0;i<5;i++) {
        framebuffer[ (cursor_y + j) + ((cursor_x+i)<<7) ]
            = (font[c-32][i] & (1<<j)) ? front_color : back_color;
      }
    }
  }
  cursor_x += 5;
  if (cursor_x >= 128) {
    cursor_x = 0;
    cursor_y += 8;
    if (cursor_y >= 128) {
      cursor_y = 0;
    }
  }
}

void display_refresh()
{
#ifndef HWFBUFFER
  unsigned char *ptr = framebuffer;
  for (int i=0;i<128*128;i++) {
    unsigned char c = (*ptr)>>2;
    ++ ptr;
    oled_pix(c,c,c);
    oled_wait();
  }
#endif
}

void dual_putchar(int c)
{
  display_putchar(c);
  uart_putchar(c);
}
