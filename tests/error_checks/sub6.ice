algorithm test(input int8 p0,output int8 o0)
{
  o0 = p0 + 10;
}

algorithm main(output int8 led)
{ 
  int8 a = 0;
  test test0;

  subroutine test0(input int8 p0,output int8 o0):
	o0 = p0 + 1;
    return;

  (led) <- test0 <- (a);

}
