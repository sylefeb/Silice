algorithm Algo(input uint8 i,output uint8 v)
{
  uint32 cycle(0);

  always_after {
    cycle = cycle + 1;
  }

  v = i;
  __display("[cycle %d] (Algo) started",cycle);
}


algorithm main(output uint8 leds)
{
  Algo alg_inst;

  uint8 a(0);

  uint32 cycle(0);
  always_after {
    cycle = cycle + 1;
  }

  while (cycle < 15) {

    __display("[cycle %d] (main) calling",cycle);
    // alg_inst.i = cycle;
    (a) <- alg_inst <- (cycle);
    __display("[cycle %d] (main) done, a = %d, alg_inst.v = %d",cycle,a,alg_inst.v);
  }

}
