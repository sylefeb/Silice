// compile_c.sh smoke/tests/leds.c --nolibc

void main() 
{
  while (1) {  
    *(volatile unsigned char*)0x90000000 = 0xaa;
    pause(10000000);
    *(volatile unsigned char*)0x90000000 = 0x55;
    pause(10000000);
  }
}

