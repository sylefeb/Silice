circuitry test(input a,output b)
{
  uint8 v = 13;
  b = a + v;
}

algorithm main(output uint8 led)
{
  uint8 a = 1;  
  (led) = test(a);
}