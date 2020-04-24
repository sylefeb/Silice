
// integer multiplication
$$mul_width = 24
$include('../common/mulint_any.ice')

algorithm main()
{
  int$mul_width$  m0      = -170;
  int$mul_width$  m1      =  121;
  int$mul_width$  result  =  0;
  
  mul$mul_width$ mul0;
  
  (result) <- mul0 <- (m0,m1);

  $display("%d * %d = %d",m0,m1,result);  
}
