
// integer multiplication
$include('../common/mulint_pipe.ice')

algorithm main()
{
  int8  m0      = 9;
  int8  m1      = 7;
  int8  result  = 0;
  
  mulpip mul0;
  
  result := mul0.ret;
  
  mul0.m0 = m0;
  mul0.m1 = m1;

++:
++:
++:

  $display("%d * %d = %d",m0,m1,result);  
}
