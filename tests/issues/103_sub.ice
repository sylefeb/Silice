subroutine readNextAligned(
  readwrites sd,
  input      uint26  addr,
  output     uint26  newaddr,
) {
  // -> read
  sd.rw           = 0;
  sd.addr         = addr;
  sd.in_valid     = 1; // go ahead!      
  newaddr         = addr + 16;
  while (sd.done == 0) { }
}

algorithm main(output uint$NUM_LEDS$ leds) 
{

}
