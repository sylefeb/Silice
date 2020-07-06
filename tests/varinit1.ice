algorithm main(output uint8 led)
{
  uint8 v1 = 1;
  uint8 v2 = 1;

  subroutine foo(output uint8 o1,input uint8 i1)
  {
    uint8 v3 = 3;
    
    v3 = i1;
    o1 = v3;
++:    
    {
      uint8 v4 = 0;
      v4 = 1 + v3;
      o1 = o1 + v4;
    }
  }
  
  v1 := 5;
  
  {
     uint8 v6 = 6;
     (led) <- foo <- (0);
  }

++:

  led = v1 + v2 + v6;

}