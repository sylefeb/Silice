
// integer multiplication
$$ mul_width = 16
$include('../common/mulint_any.ice')

algorithm main()
{
  int16  m0      = -170;
  int16  m1      =  121;
  int16  result  =  0;
  
  mul16 mul0;
  
  (result) <- mul0 <- (m0,m1);

  $display("%d * %d = %d",m0,m1,result);  
}
