algorithm alg_test(input uint1 bit_in, output uint1 bit_out)
{
   bit_out = ~bit_in;
}

algorithm main(output uint5 leds, inout uint8 pmod) {

   alg_test a(bit_in  <: pmod.i[0,1],
              // bit_out :> pmod.o[1,1] // this is not yet supported, but error message is not helpful, issue #208
              );

   pmod.oenable := 8b00000010;
   //           ^^ this means 'always set'
   pmod.o[1,1]  := a.bit_out;
   //           ^^ we can do the same here to track the output

   while (1) {
      () <- a <- ();
   }
}
