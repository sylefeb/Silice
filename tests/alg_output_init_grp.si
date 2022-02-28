group g {
  uint8 a = uninitialized,
  uint8 b = 11,
  uint8 c = 12,
}

algorithm test1(
  g gt { output a, output b, output c }
) {
  gt.a = 111;
  gt.b = 222;
  gt.c = 333;
}

algorithm main(output uint8 leds)
{
  test1 t1;
  g     g1;
  
  (g1) <- t1 <- ();

}
