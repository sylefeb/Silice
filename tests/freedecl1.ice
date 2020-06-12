algorithm main(output uint8 led)
{
  subroutine foo(output uint4 v) 
  {
    uint4 d = 1;

    v = 3;

    e = 1;

    {
      uint4 e = 10;
      v = e + 1;
    }

  }

  uint8 a = 0;
  
  a = 2;
  b = 3;
  
  {
    uint8 c = 1;
    uint8 b = 1;
  
    a = b + 1;
  }
  
  (b) <- foo <- ();
  
}
