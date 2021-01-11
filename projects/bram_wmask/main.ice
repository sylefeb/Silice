
$$config['simple_dualport_bram_wmask_byte_wenable1_width'] = 'data'

algorithm main(output uint$NUM_LEDS$ leds)
{
  simple_dualport_bram uint32 mem<"simple_dualport_bram_wmask_byte">[4096] = { pad(0) };

  mem.addr0 = 0;
  mem.addr1 = 0;
  mem.wenable1 = 4b0101;
  mem.wdata1   = 32hfedcba98;
++:
  mem.wenable1 = 4b1010;
  mem.wdata1   = 32h12345678;
++:
++:
  __display("mem.rdata0 = %h",mem.rdata0);  
  leds = mem.rdata0[0,8]|mem.rdata0[8,8]|mem.rdata0[16,8]|mem.rdata0[24,8];
}
