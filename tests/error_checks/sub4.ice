algorithm main(output int8 led)
{ 
  int8 a = 0;

  subroutine test0(input int8 p0,output int8 o0):
	o0 = p0 + 1;
    return;

  test0 <- (a); // forbidden asynch call on subroutine

}
