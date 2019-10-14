algorithm alg(input int8 i,output int8 o)
{
  o = i;
}

algorithm main(output int8 led)
{ 
  int8 a = 0;
  int8 b = 0;
  int8 c = 0;

  alg alg0;

  subroutine test(input int8 p0,output int8 o0,reads a):
	o0 = p0 + a;
    return;

  (led) <- alg0 <- (c);

  call test(b);
}
