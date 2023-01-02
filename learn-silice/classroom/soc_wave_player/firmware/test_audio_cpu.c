// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#include "config.h"
#include "std.h"

void main()
{
  int i=0;
  // get current cycle
  unsigned int last_tm = rdcycle();
  // forever
  while (1) {
    // write current sample
    *AUDIO = i;
    // check elapsed time
    int elapsed = rdcycle() - last_tm; // NOTE: beware of 2^32 wrap around on rdcycle
    if (elapsed > 3125) {
      ++i; // increment sample with chosen period
      last_tm = rdcycle();
    }
  }

}
