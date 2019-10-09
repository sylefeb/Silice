algorithm main(output int8 led)
{ 
  int8 a = 0;
  int8 b = 0;
  int8 c = 0;

  subroutine test: // (writes a, reads b, readwrites c)
    a = b + 1;
	c = c + 1;
    return;

  a = 1;
  b = 2;
  call test;
  a = a + 5;
  call test;
}
