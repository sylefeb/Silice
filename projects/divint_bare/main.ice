
// integer division
$$div_width=16
$$div_unsigned=1
$include('../common/divint_any.ice')

algorithm main(output uint8 leds)
{
  int16  dividend = 20043;
  int16  divisor  = 817;
  int16  result   = 0;
  
  div16 div0;
  
  (result) <- div0 <- (dividend,divisor);

  __display("%d / %d = %d",dividend,divisor,result);  

  leds = result[0,8];
}
