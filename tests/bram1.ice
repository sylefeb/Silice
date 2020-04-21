algorithm test(output uint8 ov,input uint8 iv)
{
  ov = iv;
}

algorithm main(output int8 v)
{
  bram uint8 table[64] = {};
  
  uint8 a = 0;
  uint8 b = 0;
  
  test tst(
    ov :> a,
    iv <: b
  );

  b = 1;
  
  table_wenable = 0;
  table_addr = 0;
  table_wdata = 133;
++:
  v = table_rdata;
++:
  __display("v = %d",v);
}
