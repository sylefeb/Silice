//   ./compile_c.sh --nolibc

// @sylefeb 2020
// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

volatile unsigned char* const LEDS = (unsigned char*)0x90000000;

void main()
{
  *LEDS = 0;

  volatile unsigned char *ptr = 0;

  for (int i=0;i<256;i++) {
    *(ptr++) = i;
  }

  ptr = 0;
  for (int i=0;i<256;i++) {
    *LEDS = *(ptr++);
  }

  while (1)  {}

}
