algorithm main(output int8 v)
{
  bram uint8 table[4] = {10,11,12,13};
  
  table.wenable = 0;
  table.addr = 0;
  table.wdata = 133;
++:
  v = table_rdata;
++:
  __display("v = %d",v);
}
