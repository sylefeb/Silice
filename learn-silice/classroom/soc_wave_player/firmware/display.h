// @sylefeb 2022
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#pragma once

void display_set_cursor(int x,int y);
void display_set_front_back_color(unsigned char f,unsigned char b);
void display_putchar(int c);
void display_refresh();
void dual_putchar(int c);
volatile unsigned char *display_framebuffer();
