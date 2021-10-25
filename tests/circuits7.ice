
group grp {
  uint8 a(10),
  uint8 b(3)
}

circuitry test_circuit(input f,input q,output o)
{
  o = f.a + f.b + q;
}

algorithm main(output uint8 leds)
{
  grp g;
  (leds) = test_circuit(g,g.a);
  __display("%d",leds);
}
