algorithm Algo(
  input  uint8 i,
  output uint8 v)
{
  always { v = i; }
}

algorithm main(output uint8 leds)
{
  uint32 cycle = 0;
  uint8  test  = 0;

  Algo alg;

  while (cycle != 32) {
    
    if (alg.i < 16) 
    {
      alg.i = cycle;
    }
    
    __display("[cycle %d] (main) alg.v = %d",cycle,alg.v);
    
    cycle = cycle + 1;
    
  }

}
