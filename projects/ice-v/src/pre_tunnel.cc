// SL 2022-03-30 @sylefeb
/*
Pre-computes a tunnel table

g++ pre_tunnel.cc -o pre_tunnel
./pre_tunnel

- outputs tunnel.h
- 320x200 resolution
- int per entry, 16 MSB v coord, 16 LSB u coord
*/

#include <cmath>
#include <iostream>
#include <fstream>

using namespace std;

int main(int argc, const char **argv)
{
  const int w = 320;
  const int h = 200;
  ofstream f("tunnel.h");

  const double scale = 255.0;

  f << "const unsigned int tunnel[] = {\n";
  for (int y = 0; y < h; ++y) {
    for (int x = 0; x < w; ++x) {
      int   cx  = w/2;
      int   cy  = h/2;
      int   dx  = (x-cx);
      int   dy  = (y-cy);
      double d  = sqrt( (double)(dx*dx + dy*dy) );
      double a  = atan2( (double)dy,(double)dx ) / M_PI;
      unsigned int d_16b = (unsigned int)round(fmod(scale * d / (1.45*(double)max(w,h)/2.0),scale));
      unsigned int a_16b = (unsigned int)round(fmod(scale/2.0 + a * scale/2.0,scale));
      unsigned int v     = (d_16b << 16) | a_16b;
      f << hex << "0x" << v << ',';
    }
    f << '\n';
  }
  f << "};\n";
  return 0;
}
