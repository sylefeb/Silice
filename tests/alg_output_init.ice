algorithm test1(
  input  uint8 a,
  input  uint8 b,
  input  uint8 c,
  output uint8 v = 112,
) {
  v = a + b + c;
}

algorithm main(output uint8 leds)
{
  test1 t1;
  
  uint8 z = 0;  
  
  (z) <- t1 <- (10,11,12);

}
