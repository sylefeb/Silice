circuitry shift_right(input a,output b,output c)
{
  b = a >>> 3;
  c = a + 1;
}

algorithm main(output uint8 led)
{
  uint8 r = 1;
  while (1) {
    (led,r) = shift_right(r);
  }
}
