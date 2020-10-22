group g
{
  uint8 value  = 0,
  uint1 enable = 0,
}

interface i_g
{
  input  value,
  output enable,
}

algorithm test(
  g           it { input value, output enable }, 
  output uint8 v
) {
  g tmp;
  tmp.value  = it.value + 1;
  v          = tmp.value;
  tmp.enable = 2;
}

algorithm main(output uint8 leds)
{
  g    foo;
  test t;
  
  foo.value = 13;
  (foo,leds) <- t <- (foo);
}

/// check dot access on algorithm group