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

#include "tunnel_text.h"
#include "tunnel_text2.h"
#include "tunnel_text3.h"
#include "tunnel_map.h"

int main(int argc, const char **argv)
{
  const int w = 320;
  const int h = 200;
  ofstream f("tunnel.h");

  const double scale = 128.0;

  f << "const unsigned int tunnel[] = {\n";
  for (int y = 0; y < h; ++y) {
    unsigned int v;
    for (int x = 0; x < w; ++x) {
      int   cx  = w/2;
      int   cy  = h/2;
      int   dx  = (x-cx);
      int   dy  = (y-cy);
      double d  =  15.0 * sqrt( (double)(dx*dx + dy*dy) );
      double a  =  atan2( (double)dy,(double)dx ) / M_PI;
      double pp = scale / d * (1.45*(double)max(w,h)/2.0);
      unsigned int d_8b = (unsigned int)round(pp);
      if (pp > scale-1.0) d_8b = (int)scale - 1;
      unsigned int a_8b = (unsigned int)max(0.0,min(scale-1.0,scale/2.0 + a * scale/2.0));
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
  f << "const unsigned int overlay1[] = {\n";
  for (int y = 0; y < h; ++y) {
    for (int x = 0; x < w; x+=32) {
      unsigned int pixels = 0;
      for (int i = 0 ; i < 32 ; ++i) {
        unsigned char pixel[3];
        HEADER_PIXEL(tunnel_text_data,pixel);
        if (pixel[0]) {
          pixels |= (1 << i);
        }
      }
      f << hex << "0x" << (unsigned int)pixels << ',';
    }
    f << '\n';
  }
  f << "};\n";
  f << "const unsigned int overlay2[] = {\n";
  for (int y = 0; y < h; ++y) {
    for (int x = 0; x < w; x+=32) {
      unsigned int pixels = 0;
      for (int i = 0 ; i < 32 ; ++i) {
        unsigned char pixel[3];
        HEADER_PIXEL(tunnel_text2_data,pixel);
        if (pixel[0]) {
          pixels |= (1 << i);
        }
      }
      f << hex << "0x" << (unsigned int)pixels << ',';
    }
    f << '\n';
  }
  f << "};\n";
  f << "const unsigned int overlay3[] = {\n";
  for (int y = 0; y < h; ++y) {
    for (int x = 0; x < w; x+=32) {
      unsigned int pixels = 0;
      for (int i = 0 ; i < 32 ; ++i) {
        unsigned char pixel[3];
        HEADER_PIXEL(tunnel_text3_data,pixel);
        if (pixel[0]) {
          pixels |= (1 << i);
        }
      }
      f << hex << "0x" << (unsigned int)pixels << ',';
    }
    f << '\n';
  }
  f << "};\n";
  f << "unsigned char texture[] = {\n";
  for (int y = 0; y < 128; ++y) {
    for (int x = 0; x < 128; ++x) {
      unsigned char pixel[3];
      HEADER_PIXEL(tunnel_map_data,pixel);
      f << hex << "0x" << (unsigned int)max(0,63-(int)pixel[0]) << ',';
    }
    f << '\n';
  }
  f << "};\n";
  return 0;
}
