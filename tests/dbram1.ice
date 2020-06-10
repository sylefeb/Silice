// Dual-port bram test

algorithm main(output uint8 led)
{
  dualport_bram uint8 mem[256]={};
  uint9 n = 0;
  uint8 tmp = 0;

  mem.wenable0 = 1;
  mem.wenable1 = 0;
  
  mem.addr0  = 0;
  mem.addr1  = 0;
  mem.wdata0 = 0;
  
  while (n < 256) {
    mem.addr0  = n;
    mem.wdata0 = n;
    mem.addr1  = n-1;
    tmp = mem.rdata1;
    $display("mem[%d] = %d",n,tmp);
    n = n + 1;
  }
  
}
