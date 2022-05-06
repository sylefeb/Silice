// Dual-port bram test, with different clocks

algorithm main(output uint8 led)
{
  
  uint9 n    = 0;
  uint9 tmp1 = 0;
  uint8 tmp2 = 0;

  uint8 cnt    = 0;

  dualport_bram uint8 mem<@clock,@cnt>[8] = {10,20,30,40,50,60,70,80};
  
  always {
    cnt = cnt + 1;  
  }
  
  mem.wenable0 = 0;
  mem.wenable1 = 0;

  while (n < 8) {
    mem.addr1 = n;
    tmp1 = n-1;
    tmp2 = mem.rdata1;
    n = n + 1;
  }
  
}
