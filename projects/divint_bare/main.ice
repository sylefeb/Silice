
// unsigned integer division
$include('../common/divint.ice')

algorithm main()
{
  uint8  dividend = 243;
  uint8  divisor  = 13;
  uint8  result   = 0;
  
  div div0;
  
  (result) <- div0 <- (dividend,divisor);

  $display("%d / %d = %d",dividend,divisor,result);  
}
