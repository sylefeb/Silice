algorithm main( 
  input  uint1 btn,
  output uint8 led
  )
{

  subroutine inc(
    input  uint8 a,
    output uint8 r)
  {
    uint8 tmp = 0;
    tmp = a + 1;
    r   = tmp;
  }

  subroutine foo(
    calls inc,
    input uint8 a
  )
  {
    uint8 tmp1 = 3;
    (tmp1) <- inc <- (a);
    tmp1 = 10;
  }

  uint8 v = 0;

  if (btn) {
    () <- foo <- (1);
  } else {
    () <- foo <- (2);
    v = 3;
  }
  {
    v = v + 1;
  }
  led = v;
}
