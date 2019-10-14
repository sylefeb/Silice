algorithm main(output int8 led)
{ 
  int8 a = 0;
  int8 b = 0;
  int8 c = 0;

  subroutine test0(input int8 p0,output int8 o0,reads a):
	o0 = p0 + a;
    return;

  subroutine test1(input int8 p0,output int8 o0):
	o0 = p0 + 3;
    return;

  (b) <- test1 <- (c);
  (led) <- test0 <- (b);

  // test <- (c); // forbidden (asynchronous calls only on algorithms)

}
