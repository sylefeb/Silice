
// integer division
$$div_width=16
$$div_unsigned=1
$include('../common/divint_std.ice')

algorithm main(output uint8 leds)
{
  int16  num    = 20043;
  int16  den    = 41;
  int16  result = 0;
  
  div16 div0;
  
  (result) <- div0 <- (num,den);

  __display("%d / %d = %d",num,den,result);  

  leds = result[0,8];

}
