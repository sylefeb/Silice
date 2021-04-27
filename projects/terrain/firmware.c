#include "../fire-v/smoke/mylibc/mylibc.h"

volatile unsigned int* const SPRAM = (unsigned int*)0x88000000;

#define MAP_SIZE (16384*2+256*3+1)

#ifdef SIMULATION
#define NUM_MAPS 1
#include "terrains.h"
#else
#define NUM_MAPS 1
#endif

unsigned char read_next()
{
#ifdef SIMULATION
  static int i = 0;
  return terrains[i++];
#else
  return spiflash_read_next();
#endif
}

void upload_map(int id)
{
  spiflash_read_begin( 0x100000/*1MB offset*/ + id*MAP_SIZE );
  // read elevation and color map
  for (int i=0 ; i< 16384 ; ++i) {
    int vl = read_next();
    int vh = read_next();
    *(SPRAM) = ((0<<30) | (i<<16) | (vh<<8) | vl);
    //           ^ SPRAM 0
  }
  // sky index
  int sky = read_next();
  // read palette
  for (int i=0 ; i<256 ; ++i) {
    int r = read_next();
    int g = read_next();
    int b = read_next();
    *(PALETTE + i)  = r | (g<<8) | (b<<16) | (i == sky ? (1<<24) : 0);
  }
  // done
  spiflash_read_end();
}

void main()
{
  int select      = 0;
  int delay       = 0;
  int upload_next = 1;

  spiflash_init();
  while (1) {
    if (upload_next) {
      upload_next = 0;
      upload_map(select);
    }
    if (((userdata()&48) == 48) && delay == 0) { // two buttons pressed at once
      ++ select;
      if (select >= NUM_MAPS) {
        select = 0;
      }
      upload_next = 1;
      delay       = 1000000;
    }
    if (delay > 0) --delay;
  }

}
