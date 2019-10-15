algorithm main(output int8 led)
{ 
  int8 a = 0;
  int8 b = 0;
  int8 c = 0;

  subroutine test0(input int8 p0,output int8 o0):  // missing permission: ,reads a):
	o0 = p0 + a;
    return;

  (led) <- test0 <- (b);

}
