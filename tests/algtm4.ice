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
  uint8 a(0);
  uint8 b(0);

  Algo alg_inst(
    i <: cycle,
    v :> a
  );

  uint32 cycle(0);
  always_after {
    cycle = cycle + 1;
  }

  while (cycle < 15) {

    __display("[cycle %d] (main) calling",cycle);
    (b) <- alg_inst <- ();
    __display("[cycle %d] (main) done, a = %d, b = %d, alg_inst.v = %d",cycle,a,b,alg_inst.v);
  }

}
