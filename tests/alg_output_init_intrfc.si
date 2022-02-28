group g {
  uint8 a = uninitialized,
  uint8 b = 11,
  uint8 c = 12,
}

interface f {
  output a, 
  output b, 
  output c
}

algorithm test1(
  f gt
) {
  gt.a = 111;
  gt.b = 222;
  gt.c = 333;
}

algorithm main(output uint8 leds)
{
  g     g1;
  // test1 t1; // triggers error
  test1 t1(gt <:> g1);
  
  // leds = g1.a + g1.b + g1.c;
}
