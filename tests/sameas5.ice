group g
{
  uint8 value   = -27,
}

interface i_g
{
  input  value,
}

algorithm test(
  i_g    it,
  output int8 v
) {
  sameas(it.value) tmp1 = uninitialized;
  tmp1        = widthof(it.value) - 100;
  
  if (it.value < 0) {
    __display("below zero!");
  } else {
    __display("above zero!");
  }
  __display("it.value = %d",it.value);
  
  v           = tmp1;
}

algorithm main(output uint8 leds)
{
  g           foo;
  g           bar;
  
  
  
  test t(it <:> foo);
  
  (leds) <- t <- ();
}
