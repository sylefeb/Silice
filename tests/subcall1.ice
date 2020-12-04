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

  subroutine foo(input uint8 a)
  {
    uint8 tmp1 = 3;
    tmp1 = a;
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
