algorithm Algo(
  input  uint4 h,
  input  uint4 l,
  output uint8 v)
{
  always {
    v = {h,l};
  }
}

bitfield bf { uint4 a,uint4 b }

algorithm main(output uint8 leds)
{
  uint32 cycle = 0;
  uint8  test  = 0;

  Algo alg_inst(
    h  <: cycle[1,4],
    l  <: bf(cycle).a,
    v  :> test
  );

  while (cycle != 32) {
    __display("[cycle %d] (main) test = %b",cycle,test);
    cycle = cycle + 1;
  }

}
