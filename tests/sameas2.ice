group g
{
  uint8 value  = 333,
  uint1 enable = 1,
}

interface i_g
{
  input  value,
  output enable,
}

algorithm test(
  i_g    it,
  output uint8 v
) {
  sameas(it)   tmp1;
  sameas(tmp1) tmp2;
  tmp1.value  = it.value + 1;
  v           = tmp1.value;
  tmp1.enable = 1;
  tmp2.value  = it.value + 33;
  tmp2.enable = tmp1.enable;
  it.enable   = 0;
}

algorithm main(output uint8 leds)
{
  g           foo;
  sameas(foo) bar;
  
  test t(it <:> foo);
  
  foo.value = 13;
  // (foo,leds) <- t <- ();
  (bar,leds) <- t <- ();
  // () <- t <- ();
}
