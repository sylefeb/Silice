circuitry shift_right(input uint8 a,output uint8 b,output uint8 c)
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
