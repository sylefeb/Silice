
circuitry bla(input i,output o)
{
  o = i;
}

algorithm main(output uint8 led)
{
  subroutine foo(output uint8 o) 
  {
     uint8 sa = 0;
     
     o = sa;
  }

  uint8 a = 1;  
  a = 2;
  {
    uint8 b = 3;
    a = b;
  }
++:
  {
    uint8 b = 4;
    a = b;
  }
++:
  {
    uint8 a = 4;
    led = a;
    a = 1000;
  }
++:
  (led) <- foo <- ();
++:
  {
    uint8 e = 0;
    e = 12;
    (led) = bla(e);
  }
++:  
  // a = b;
  led = a;
}
