
// defines a variable group
group table {
  uint2 addr  = 0,
  uint8 rdata = 0
}

// defines an interface compatible with the group
interface port {
  input   rdata,
  output! addr // we ask for combinational output
}

algorithm test(
  port access
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
  table t;
  
  test tst(
    access <::> t // :: is used to delay the inputs to next clock cycle
                  // this prevents forming a combinational cycle and 
                  // achieves the desired one cycle latency
  );

  uint8 n = 0;
  while (n < 32) {
    switch (t.addr) {
      case 0 : {t.rdata = 100;}
      case 1 : {t.rdata = 110;}
      case 2 : {t.rdata = 120;}
      case 3 : {t.rdata = 130;}
      default: {t.rdata = 255;}
    }
    n = n + 1;
  }
 
}
