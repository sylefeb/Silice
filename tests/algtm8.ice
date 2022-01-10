algorithm alg1(input uint8 i,output uint8 v)
{
  always { v = i + 1; }
}

algorithm alg2(input uint8 i,output uint8 v)
{
  always { v = i + 10; }
}

algorithm main(output uint8 leds)
{
  uint32 cycle = 0;

  alg1 a1(i <: cycle);
  alg2 a2(i <: a1.v);

  while (cycle != 32) {
    
    __display("[cycle %d] (main) a2.v = %d",cycle,a2.v);
    
    cycle = cycle + 1;
    
  }

}
