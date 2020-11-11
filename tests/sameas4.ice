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
  sameas(it.value) tmp1;
  tmp1        = widthof(it.value) + 3;
  v           = tmp1;
}

algorithm main(output uint8 leds)
{
  g           foo;
  g           bar;
  
  test t(it <:> foo);
  
  (bar,leds) <- t <- ();
}
