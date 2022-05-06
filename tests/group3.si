group test {
  uint9  a(10),
  uint9  b = uninitialized,
  uint11 c = uninitialized,
}

interface i_test {
  input  a, // (1), // would trigger an error (expected) as init value of inputs come from the group
	output b(5),
	output c(6),
}

algorithm foo(i_test t)
{
  t.b = t.a;
  t.c = t.a;
}

algorithm main(output uint8 leds)
{
	test t;

  foo f(t <:> t);
	
	__display("t.a = %d, t.b = %d, t.c = %d",t.a,t.b,t.c);
	
}
