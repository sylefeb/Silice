
algorithm main()
{

  uint16 val        = 231;
  uint16 reciprocal = 199Ah
  uint32 tmp = 0;
  uint16 res = 0;
  
  tmp = val * reciprocal;
  
  res = (tmp >> 16);

  $display("result = %d",res);

}

