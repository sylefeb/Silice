// MIT license, see LICENSE_MIT in Silice repo root
// #include "../mylibc/mylibc.h"
/*
void pause(int cycles)
{ 
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}
*/
void main() 
{
  int offset = 0;

  while (1) {
    for (int j = 0 ; j < 480 ; j++) {
      for (int i = 0 ; i < 640 ; i++) {
         *(volatile unsigned char*)(0x00000000 | (i + (j << 10))) = (unsigned char)(offset+i);
         //pause(10);
      }
    }
    ++offset;  
  }
}
