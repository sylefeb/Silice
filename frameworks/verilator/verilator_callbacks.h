#pragma once

// declare here all callbacks visible to designs

int  data(int addr);
void data_write(int wenable,int addr,unsigned char byte);
void set_vga_resolution(int w,int h);
int  get_random();
void output_char(int c);
