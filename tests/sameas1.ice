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
  sameas(it) tmp;
  tmp.value  = it.value + 1;
  v          = tmp.value;
  tmp.enable = 1;
  it.enable  = 0;
}

algorithm main(output uint8 leds)
{
  g    foo;
  g    bar;
  
  test t(it <:> foo);
  
  foo.value = 13;
  // (foo,leds) <- t <- ();
  (bar,leds) <- t <- ();
  // () <- t <- ();
}
