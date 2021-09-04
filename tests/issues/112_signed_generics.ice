
group grp1 {
  int8  a=0,
  int8  b=0,
  uint1 c=0,
}

group grp2 {
  int10 a=0,
  int10 z=0,
}

interface itrf1 {
  input a, output b, input c
}

interface itrf2 {
  output a, input z
}

algorithm test2(
  itrf2 g
) {
  g.a = g.z + 1;
}

algorithm test(
  itrf1 g
) {
  grp2 h;
  test2 t2(
    g <:> h
  );
  h.z = g.a;
  () <- t2 <- ();
  if (g.c) {
    __display("TRUE  %b",g.c);
  } else {
    __display("FALSE %b",g.c);  
  }
  __display("h.a = %d",h.a);
}

algorithm main(output uint8 leds)
{
  grp1 g;
  test tst(
    g <:> g
  );

  sameas(g) f;
  test tst2(
    g <:> f
  );

  g.a = -33;
  f.a = -33;
  g.c = 0;
  f.c = 1;

  () <- tst  <- ();
  () <- tst2 <- ();

   leds = g.b;

  __display("G %d",g.b);
  __display("F %d",f.b);

  
}
