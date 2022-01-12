// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2021
// https://github.com/sylefeb/Silice
#pragma once

#include "config.h"

#define OLED_CMD   (1<< 9)
#define OLED_DTA   (1<<10)
#define DELAY      (1<<18)

#define OLED_666 0
#define OLED_565 1

void oled_init_mode(int mode);
void oled_init();
void oled_fullscreen();
void oled_clear(unsigned char c);

static inline void oled_wait() { asm volatile ("nop; nop; nop; nop; nop; nop; nop;"); }

static inline void oled_pix(unsigned char r,unsigned char g,unsigned char b)
{
    *(OLED) = OLED_DTA | b;
    oled_wait();
    *(OLED) = OLED_DTA | g;
    oled_wait();
    *(OLED) = OLED_DTA | r;
}

static inline void oled_pix_565(unsigned char b5g3,unsigned char g3r5)
{
    *(OLED) = OLED_DTA | b5g3;
    oled_wait();
    *(OLED) = OLED_DTA | g3r5;
}

static inline void oled_comp(unsigned char c)
{
    *(OLED) = OLED_DTA | c;
}
