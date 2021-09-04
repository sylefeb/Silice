algorithm main(output uint8 led)
{

  subroutine inc(input uint8 a,output uint8 r)
  {
    uint8 tmp = 0;
    tmp = a + 1;
    r   = tmp;
  }

  subroutine foo(input uint8 a,output uint8 r)
  {
    uint8 tmp1 = 3;
    uint8 tmp2 = 0;
    tmp2 = a;
    while (tmp1 > 0) {
      tmp1 = tmp1 - 1;
      tmp2 = tmp2 + a;
    }
    r = tmp2;
  }

  uint8 v = 0;

  (v) <- inc <- (v);
  (v) <- foo <- (v);

}
