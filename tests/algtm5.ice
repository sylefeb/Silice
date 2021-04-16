algorithm Algo(input uint8 i,output uint8 v)
{
  always {
    v = i;
  }
}

algorithm main(output uint8 leds)
{
  uint32 cycle = 0;

  Algo alg_inst(
    i <: cycle
  );

  while (cycle != 16) {
    __display("[cycle %d] (main) alg_inst.v = %d",cycle,alg_inst.v);
    cycle = cycle + 1;
  }

}
