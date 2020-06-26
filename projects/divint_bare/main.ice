
// integer division
$include('../common/divint16.ice')

algorithm main()
{
  int16  dividend = 20043;
  int16  divisor  = -817;
  int16  result   =  0;
  
  div16 div0;
  
  (result) <- div0 <- (dividend,divisor);

  __display("%d / %d = %d",dividend,divisor,result);  

}
