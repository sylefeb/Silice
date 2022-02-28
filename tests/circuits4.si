circuitry test_circuit(input a,output b)
{
  b = a;
}

algorithm main(output uint8 led)
{
  uint4 tbl1[3] = {0,0,0};
  uint4 tbl2[3] = {0,0,0};
  (tbl2[2]) = test_circuit(tbl1[0]); // not possible, expected  to trigger an error
}
