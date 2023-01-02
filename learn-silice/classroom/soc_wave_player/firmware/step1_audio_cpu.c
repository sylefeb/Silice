// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

// Once Step 1 completed, this firmware produces a varying tune
// that can be listened to on the audio port

// ==================================================================
// ** WARNING ** High-pitch high-volume sounds! Do NOT use a helmet!
// ==================================================================

#include "config.h"
#include "std.h"

void main()
{
  int i=0;
  // get current cycle
  unsigned int last_tm = rdcycle();
  const int period_min = 3125;
  const int period_max = 3125 * 6;
  int dir    = 1;
  int period = period_min;
  // forever
  while (1) {
    // write current sample
    *AUDIO = i;
    // check elapsed time
    int elapsed = rdcycle() - last_tm; // NOTE: beware of 2^32 wrap around on rdcycle
    if (elapsed > period) {
      // increment sample (sawtooth wave)
      ++i;
      // change period progressively
      if (period >= period_max) { dir = -1; }
      if (period <= period_min) { dir =  1; }
      period += dir;
      // record time
      last_tm = rdcycle();
    }
  }

}
