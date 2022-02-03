algorithm alg_test(input uint1 bit_in, output uint1 bit_out)
{
   bit_out = ~bit_in;
}

group gr {
  uint8 p = 0,
}

algorithm main(output uint5 leds, inout uint8 pmod) {

  gr g;
  uint1 v = 1;

   alg_test a(bit_in  <: pmod.i[0,1],
              bit_out :> pmod.o[1,1],
              bit_out :> pmod.o[4,1], // interesting, we can bind bit_out a second time!
    );

   pmod.oenable := 8b00000010;
	 //           ^^ this means 'always set'

   while (1) {
      () <- a <- ();
      __display("%d",pmod.o[4,1]);
   }
}
