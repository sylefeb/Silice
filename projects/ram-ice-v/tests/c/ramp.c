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
    for (int j = 0 ; j < 200 ; j++) {
      for (int i = 0 ; i < 320 ; i++) {
         *(volatile unsigned char*)(0xA0000000 | (i + (j << 9))) = (unsigned char)(offset+i);
         //pause(10);
      }
    }
    ++offset;  
  }
}
