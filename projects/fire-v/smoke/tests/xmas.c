#include "../mylibc/mylibc.h"

void draw(int xpos,int xlen,unsigned char color)
{
    for (int i = -xlen/2 + xpos; i <= xlen + xpos ; i ++) {
      *(FRAMEBUFFER + i + (40<<9) ) = color;
    }
}

void talk(int start,int length)
{
  int  count   = start;
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
      draw(80 + 160 * cpuid(), 1 + prev_sample/4, 0);
      // draw new bar
      draw(80 + 160 * cpuid(), 1 + sample/4 , 255);
      // record previous
      prev_sample = sample;
    }
  }
  // clear bars
  for (int j = 0; j < 8 ; j++) {
    draw(80 + 160 * cpuid(), 64 , 0);
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

void play(volatile unsigned char *from,int length)
{
  long tm_prev = time();
  while (length > 0) {
    if (time() - tm_prev > 4535) { // sampling rate (11025 kHz at 50 MHz CPU)
      // sample and emit sound
      unsigned char sample = *(from++);
      *(AUDIO) = sample;
      // next
      tm_prev = time();
      -- length;
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

void drawImage(volatile unsigned char *data)
{
  volatile unsigned char *src = data;
  volatile unsigned char *dst = FRAMEBUFFER;
  for (int j = 0 ; j < 200 ; j++) {
    for (int i = 0 ; i < 320 ; i++) {
      *dst = *src;      
      ++ dst;
      ++ src;
    }    
    dst += 192; // 512-320
  }
}

unsigned char backgroundAt(int x,int y_9) 
{
  return *(DATA + x + (y_9>>1) + (y_9>>3)); // x + y * 320
}

unsigned int rand = 0xfa5e7fc1;

unsigned int rand_next()
{
  rand = ((rand << 3) ^ 1103515245 ^ (rand >> 3)) + 40847;
  return rand;
}

unsigned int rand_next_slow()
{
  for (int i = 0; i < 3; i++) {
    rand_next();
  }
  return rand_next();
}

#define NUM_FLAKES 4096

typedef struct {
  unsigned short x;
  int            y;
} t_flake;

t_flake flakes[NUM_FLAKES];

int rand_x()
{
  while (1) { // slow but init only
    int r = rand_next_slow() & 511;
    if (r < 320) { return r; }
  }  
}

int rand_y()
{
  while (1) { // slow but init only
    int r = rand_next_slow() & 255;
    if (r < 200) { return r; }
  }  
}

int rand_xdelta()
{
  if ((rand_next() & 3) == 0) {    
    int r = (rand_next() & 1);
    return r;
  }
  return 0;
}

void init_snow()
{
  set_cursor(0,0);
  for (int f = 0; f < NUM_FLAKES; f++) {
    flakes[f].x = rand_x();
    flakes[f].y = rand_y() << 9;
    // printf("flake %d x%d y%d\n",f,flakes[f].x,flakes[f].y);
  }
}

void snow()
{  
  int frame = 0;

  while (*(FRAMEBUFFER+163840) == 0) { // ad vitam aeternam

    int r = rand_next();

    for (int f = 0; f < NUM_FLAKES; f++) {

      unsigned char type = f < (NUM_FLAKES/4) ? 1 : 0;

      if (backgroundAt(flakes[f].x,flakes[f].y) == 0 || ( ((r+f)&255) == 0 ) || (type == 1)) {
        // pointer from coords
        volatile unsigned char *ptr = FRAMEBUFFER + flakes[f].x + flakes[f].y;
        int xdelta = rand_xdelta();
        int ydelta = ((frame&1) || type == 0) ? 512 : 0;
        // erase previous
        *ptr      = 0;
        // update        
        ptr      += ydelta;
        ptr      += xdelta; // could exit the framebuffer, oh well
        // write new
        *ptr      = type ? 128 : 255;
        // update in struct
        int new_y   = flakes[f].y + ydelta;
        int new_x   = flakes[f].x + xdelta;
        flakes[f].y = new_y < (200<<9) ? new_y : 0;
        flakes[f].x = new_x < (320) ? (new_x >= 0 ? new_x : 319) : 0;
      }
    }

    ++ frame;

    int count = 0;
    while (count < 800000) { ++count; }

  }
}

void main() 
{
  int wave_table[10] = {
    340473, 41784, // cpu0
    382257, 31416, // cpu1
    413673, 15576, // xmas1
    429249, 14136, // xmas2
    443385, 50136 // friend
  };

  if (cpuid() == 0) {
    clear_screen(0);
  } else {
    clear_screen(100);
  }

  if (cpuid() == 0) {

    play(DATA + 64000, 276473);    

    pause(20000000);

    talk(wave_table[0],wave_table[1]);

    *(FRAMEBUFFER+163840) = 255; // music + talk done, stop snow

    silent(wave_table[2],wave_table[3]);
    talk  (wave_table[4],wave_table[5]); // xmas

    silent(wave_table[8],wave_table[9]);
    pause(20000000);

    for (int count = 0; count < 50000000 ; count ++) {
      set_cursor(100,150);
      printf("Merry Xmas my friends!");
    }
    for (int count = 0; count < 50000000 ; count ++) {
      set_cursor(100,150);
      printf("Merry Xmas my friends!");
    }

  } else {

    // drawImage(DATA);
    *(FRAMEBUFFER+163840) = 0; // music done tag init

    set_cursor(0,0);
    init_snow();
    snow();

    talk(wave_table[2],wave_table[3]);
    talk(wave_table[6],wave_table[7]); // xmas

    talk(wave_table[8],wave_table[9]);

    *(FRAMEBUFFER+163840) = 0; // music done tag init
    snow();

  }

}
