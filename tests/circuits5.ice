circuitry test_circuit(input a,inout mem,output b)
{
  mem.addr = a;
++:
  b = mem.rdata;  
}

algorithm main(output uint8 led)
{
  bram uint8 test_mem[] = {1,2,3,4,5,6};
  uint8 a = 3;
  (mem,led) = test_circuit(a,test_mem);
}
