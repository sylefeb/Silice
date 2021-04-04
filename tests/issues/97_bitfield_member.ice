bitfield test{
  uint1 one,
  uint7 seven
}

group grp {
  uint8 a=0,
  uint8 b=0
}

algorithm foo(input grp f,output uint8 o)
{
  o = test(f.b).one;
}

algorithm bar(input uint8 i,output uint8 o)
{
  o = i;
}

algorithm main(output uint8 leds)
{
  grp g;
  foo ff;
  bar bb;
++:  
  (leds) <- ff <- (g);
}
