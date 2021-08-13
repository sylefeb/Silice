int* const LEDS = (int*)0x1004;

void leds(unsigned char l)
{
  *(LEDS) = l;
}

void main() 
{

  leds(3);
  leds(10);
  leds(3);
  leds(10);

}
