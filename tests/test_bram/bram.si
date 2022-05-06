algorithm main(output uint$NUM_LEDS$ leds)
{
  simple_dualport_bram 
  // dualport_bram 
  // brom
  // bram
  int$NUM_LEDS$ mem[256] = {
$$for i=0,255 do
    $math.floor(511.0 * math.cos(2*math.pi*i/255))$,
$$end
};
  
  // mem.wenable := 0;
  // mem.wenable  = 0;
  
  mem.addr0    = 0;
  while (1) {    
    leds      = mem.rdata0;
    mem.addr0 = mem.addr0 + 1;
  }

}
