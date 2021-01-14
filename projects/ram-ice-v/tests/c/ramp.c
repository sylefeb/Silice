
void main() 
{

  int offset = 0;

  //while (1) {
  
    for (int j = 0 ; j < 1 ; j++) {
      for (int i = 0 ; i < 1 ; i++) {
        // *(volatile unsigned char*)(i + (j << 9)) = (unsigned char)(offset+i);
        *(volatile unsigned char*)(0x20000000) = (unsigned char)(offset+i);
      }
    }
    ++offset;  
  //}
  asm(".word 0\n"); // SL: halts CPU

}
