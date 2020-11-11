
// interface compatible with the bram port
interface memory_port {
  input   rdata,
  output! addr // we ask for combinational output
}

algorithm test(
  memory_port access
) <autorun> {  

++: // let main start (loop entry)

  access.addr = 3;
++:
  {
      uint16 v = 0;
      v = access.rdata;
      __display("access[3] = %d",v);
  }
  access.addr = 1;
++:
  {
      uint16 v = 0;
      v = access.rdata;
      __display("access[1] = %d",v);
  }
  access.addr = 2;
++:
  {
      uint16 v = 0;
      v = access.rdata;
      __display("access[2] = %d",v);
  }
  access.addr = 0;
++:
  {
      uint16 v = 0;
      v = access.rdata;
      __display("access[0] = %d",v);
  }
}

algorithm main()
{
  bram uint8 table[4] = {10,11,12,13};
  
  test tst(
    access <:> table
  );

  uint8 n = 0;
  while (n < 32) {
    n = n + 1;
  }
 
}
