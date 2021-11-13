// MIT license, see LICENSE_MIT in Silice repo root
// @sylefeb 2020
// https://github.com/sylefeb/Silice

#include "../mylibc/mylibc.h"

void draw(int xpos,int xlen,int y,unsigned char color)
{
    for (int i = -xlen/2 + xpos; i <= xlen + xpos ; i ++) {
      *(FRAMEBUFFER + i + (100<<9) ) = color;
    }
}

void talk(int start,int length)
{
  int  count = start;
  long tm_prev = time();
  unsigned char prev_sample = 0;
  while (count <= start + length) {
    if (time() - tm_prev > 4535) { // sampling rate (11025 kHz at 50 MHz CPU)
      // sample and emit sound
      unsigned char sample = (*(DATA + count));
      *(AUDIO) = sample;
      // next
      tm_prev = time();
      ++ count;
      // erase previous bar
      draw(80 + 160 * cpuid(), 1 + prev_sample/4, 100 , 0);
      // draw new bar
      draw(80 + 160 * cpuid(), 1 + sample/4 , 100 , 255);
      // record previous
      prev_sample = sample;
    }
  }
  // clear bars
  for (int j = 0; j < 8 ; j++) {
    draw(80 + 160 * cpuid(), 64 , 100+j , 0);
  }
}

void silent(int start,int length)
{
  int  count = start;
  long tm_prev = time();
  while (count <= start + length) {
    if (time() - tm_prev > 4535) { // sampling rate (11025 kHz at 50 MHz CPU)
      unsigned char sample = (*(DATA + count));
      tm_prev = time();
      ++ count;
    }
  }
}

void clear_screen(int jstart)
{
  for (int j = jstart ; j < jstart + 100 ; j++) {
    for (int i = 0 ; i < 320 ; i++) {
      *(FRAMEBUFFER + i + (j << 9)) = 0;
    }
  }
}

void pause(int cycles)
{
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

void main()
{
  int wave_table[14] = {
    0     , 34296, // hi left
    34296 , 28536, // hi right
    62832 , 36600, // say left
    99432 , 31704, // say right
    131136, 34872, // hi sorry
    166008, 66264, // come on
    232272, 28616  // he is right
  };

  // intro

  if (cpuid() == 0) {

    clear_screen(0);
    talk  (wave_table[0],wave_table[1]);
    silent(wave_table[2],wave_table[3]);
    talk  (wave_table[6],wave_table[7]);

    pause(10000000);
    pause(10000000);
    pause(10000000);
    pause(20000000);
    pause(50000000);
    pause(50000000);

    talk  (wave_table[8],wave_table[9]);
    silent(wave_table[10],wave_table[11]);

    clear_screen(100);
    pause(30000000);

    set_cursor(80,170);
    printf("Hey! ");
    pause(10000000);
    printf("I am ");
    pause(10000000);
    printf("a ");
    pause(10000000);
    printf("framebuffer ");
    pause(10000000);
    printf("not a ");
    pause(10000000);
    printf("GPU! ");

    set_cursor(80,190);
    printf("Plus, ");
    pause(50000000);
    printf("you ");
    pause(10000000);
    printf("draw ");
    pause(10000000);
    printf("your ");
    pause(10000000);
    printf("own ");
    pause(10000000);
    printf(" graphics!");

    pause(50000000);
    pause(50000000);

    talk  (wave_table[12],wave_table[13]);

  } else {

    clear_screen(100);
    silent(wave_table[0],wave_table[1]);
    talk  (wave_table[2],wave_table[3]);
    talk  (wave_table[4],wave_table[5]);

    set_cursor(80,150);
    printf("And ");
    pause(10000000);
    printf("who ");
    pause(10000000);
    printf("draws ");
    pause(10000000);
    printf("the graphics, ");
    pause(20000000);
    printf(" hmmmm?");

    pause(50000000);
    pause(50000000);

    silent(wave_table[8],wave_table[9]);
    talk  (wave_table[10],wave_table[11]);

    pause(30000000); // Hey ...
    pause(50000000);

    pause(50000000); // Plus ...
    pause(50000000);

    pause(50000000);

    silent (wave_table[12],wave_table[13]);

    clear_screen(100);
    set_cursor(80,150);
    printf("Yeah, ");
    pause(10000000);
    printf("CPUs ");
    pause(10000000);
    printf("have ");
    pause(10000000);
    printf("become ");
    pause(20000000);
    printf("lazy!");

  }

}
