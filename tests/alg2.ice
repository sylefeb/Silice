algorithm adder(input int8 a,input int8 b,output int8 v) <autorun>
{
  loop:
    v = a + b;
  goto loop;
}

algorithm main(output int8 led)
{
  int8 r = 0;
  adder a1;
  
  a1.a = 1;
  a1.b = 2;
++:
  r = a1.v + 2;
}
