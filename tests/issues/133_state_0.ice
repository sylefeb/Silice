algorithm main(output uint$NUM_LEDS$ leds = 0)
{
  uint8 b(111);

  uint8 a(0);
  a := b + 1;

  if (reset) { __display("in reset %d",b); } // we can see state 0 executing while in reset...

  leds = a;
  b    = 0;
  
++:
  __display("======> %d <<< should be 112", leds); 
  
}
