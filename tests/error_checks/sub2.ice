algorithm main(output int8 led)
{ 
  int8 a = 0;
  int8 b = 0;
  int8 c = 0;

  subroutine test0(input int8 p0,output int8 o0) {  // missing permission: ,writes a):
	a = p0 + 1;
	o0 = p0;
    return;
  }

  (led) <- test0 <- (b);

}
