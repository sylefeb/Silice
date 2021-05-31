algorithm main(output uint$NUM_LEDS$ leds = 0)
{
  uint8 b(111);
  uint8 a <: b + 1;

  b    = 0; // removing this makes everyone agree
  leds = a;
  b    = 28;
  
  // Q: is the value of leds 1, or 29 ?

++:
  __display("======> %d", leds); 
  
}
