algorithm test(
  input  uint1 a,
  input  uint1 b,
  input  uint1 c,
  output uint8 v
) {
  v = a + b + c;
}

algorithm main(output uint8 leds)
{
  uint1 z = 0;

  test t(c <: z);
  
  t.a = 10;
  t.b = 11;
  () <- t <- ();

//  () <- t <- (10,11,12); // triggers error
  
}
