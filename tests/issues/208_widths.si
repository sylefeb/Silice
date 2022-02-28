algorithm alg_test(input uint1 bit_in, output uint1 bit_out)
{
   bit_out = ~bit_in;
}

group gr {
  uint8 p = 0,
}

algorithm main(output uint5 leds, inout uint8 pmod) {

  uint2 v = 1;

  alg_test a(bit_in  <: pmod.i[0,1],
             bit_out :> v[10,1], // v does not have that many bits
             bit_out :> v[0,2], // bit_out is not wide enough
  );

  () <- a <- ();
  __display("%d",v);
}
