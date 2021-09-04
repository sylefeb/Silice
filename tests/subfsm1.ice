
algorithm main(output uint8 leds)
{

  subroutine foo(input uint8 v,output uint8 o)
  {
    uint8 t = uninitialized;
    t = v + 1;
++:  
    o = t + 1;
  }
 
  (leds) <- foo <- (100);

}
