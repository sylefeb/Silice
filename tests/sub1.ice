algorithm main(output int8 led)
{ 
  int1 a = 0;

  subroutine test:
    a = a + 1;  
    return;

  a = 2;
  call test;
  a = a + 5;
  call test;
}
