algorithm main(output int8 led)
{ 
  int8 a = 0;
  int8 b = 0;
  int8 c = 0;

  subroutine test0(input int8 p0,output int8 o0,reads a) {  // missing permission: ,readwrites a):
	o0 = a + 1;
	a = p0;
    return;
  }

  (led) <- test0 <- (b);

}
