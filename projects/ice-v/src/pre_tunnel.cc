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

  const double scale = 127.0;

  f << "const unsigned int tunnel[] = {\n";
  for (int y = 0; y < h; ++y) {
    unsigned int v;
    for (int x = 0; x < w; ++x) {
      int   cx  = w/2;
      int   cy  = h/2;
      int   dx  = (x-cx);
      int   dy  = (y-cy);
      double d  =  10.0 * sqrt( (double)(dx*dx + dy*dy) );
      double a  =  0.75 * atan2( (double)dy,(double)dx ) / M_PI;
      double pp = scale / d * (1.45*(double)max(w,h)/2.0);
      unsigned int d_8b = (unsigned int)round(pp);
      if (pp > 127.0) d_8b = 127;
      unsigned int a_8b = (unsigned int)round(fmod(scale/2.0 + a * scale/2.0,scale));
      unsigned int p    = (a_8b << 7) | d_8b;
      if (x&1) {
        v = v | (p << 16);
        f << hex << "0x" << v << ',';
      } else {
        v = p;
      }
    }
    f << '\n';
  }
  f << "};\n";
  return 0;
}
