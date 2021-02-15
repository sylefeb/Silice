volatile unsigned int*  const TRIANGLE    = (unsigned int*)0x88000000;

inline long my_userdata() 
{
  int id;
  asm volatile ("rdtime %0" : "=r"(id));
  return id;
}

void main()
{

  *(TRIANGLE+11) = 0;
  *(TRIANGLE+14) = 155            | (3<<16);
  *(TRIANGLE+15) = ((-155)&65535) | ((-3)<<16);
  *(TRIANGLE+ 6) = (78)           | (7<<16);

  // wait for divisions to complete
  while ((my_userdata()&32) == 32) {  }

}
