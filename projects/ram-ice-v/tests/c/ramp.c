
void main() 
{

  int offset = 0;

  while (1) {
  
    for (int j = 0 ; j < 200 ; j++) {
      for (int i = 0 ; i < 320 ; i++) {
        *(volatile unsigned char*)(i + (j << 9)) = (unsigned char)(offset+i);
      }
    }
    ++offset;
  
  }

}
