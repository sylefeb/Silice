// MIT license, see LICENSE_MIT in Silice repo root

// integer division
$$div_width=8
$$div_unsigned=1
$include('../common/divint_std.ice')

algorithm main(output uint8 leds)
{
  uint8  num    = 192;
  uint8  den    = 192;
  uint8  result = 0;
  
  div8 div0;
  
  (result) <- div0 <- (num,den);

  __display("%d / %d = %d",num,den,result);  

  leds = result[0,8];

}
