#include "../fire-v/smoke/mylibc/mylibc.h"

volatile unsigned int* const SPRAM = (unsigned int*)0x88000000;

#define MAP_SIZE (16384*2+16*3+1)
#define NUM_MAPS 6

void upload_map(int id)
{
  spiflash_read_begin( 0x100000/*1MB offset*/ + id*MAP_SIZE );
  // read elevation and color map
  for (int i=0 ; i< 16384 ; ++i) {
    int vl = spiflash_read_next();
    int vh = spiflash_read_next();
    *(SPRAM) = ((0<<30) | (i<<16) | (vh<<8) | vl);
    //           ^ SPRAM 0
  }
  // sky index
  int sky = spiflash_read_next();
  // read palette
  for (int i=0 ; i<16 ; ++i) {
    int r = spiflash_read_next();
    int g = spiflash_read_next();
    int b = spiflash_read_next();
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

    if (((userdata()&48) == 48) && delay == 0) { // two button pressed at once
      ++ select;
      if (select >= NUM_MAPS) {
        select = 0;
      }
      upload_next = 1;
      delay       = 1000000;
    }

    if (delay > 0) --delay;

    // TODO: change palette for night / day?

  }

}
