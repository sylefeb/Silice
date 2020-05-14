group test {
  uint8  a = 0,
  uint9  b = 2,
  uint11 c = 4hf0
}

algorithm foo(
  test tin {
    input a,
    output b,
    output c
  }
) {
  
}

algorithm alg(
  output uint8 led,
  test t0 {
    input a,
    output b,
    output! c
  }
) {

  foo f(tin <:> t0);

  test bla;
  
  bla.b = 5;

  t0.c = t0.a;
}
