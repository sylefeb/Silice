// @sylefeb 2022-01-10
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

// Once Step 0 completed, this firmware produces a back
// and forth "knight rider" pattern on the LEDs

#include "config.h"
#include "std.h"

void main()
{
  int leds = 1;
  int dir  = 0;
  while (1) {
    pause(1000000);
    if (leds == 128 || leds == 1) { dir = 1-dir; }
    if (dir) {
      leds = leds << 1;
    } else {
      leds = leds >> 1;
    }
    *LEDS = leds;
  }
}
