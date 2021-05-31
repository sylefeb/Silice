algorithm main(output uint8 leds)
{

  uint8 a(1);
  uint8 c(0);

  uint8 b <: a + 1;
  
  c = b;
  a = 10;

  leds = c;
  // __display("c %d",c);

}
