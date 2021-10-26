bitfield HL16 {
  uint8 h,
  uint8 l
}

bitfield HL8 {
  uint4 h,
  uint4 l
}

group grp {
  uint8 h(8hcd),
  uint8 l(8hef)
}

algorithm main(output uint8 leds)
{
  uint16 data = 16hcdef;
  uint16 tbl[4] = {16habcd,16h1234,0,0};

  grp g;

  // unsupported cases, expected to trigger an error
  //
  // __display("%x", HL8(HL16(data).h).h );
  // __display("%x", data[8,8][4,4] );

  // cases that are working as expected
  //
  // __display("%x", g.h[4,4] );
  // __display("%x", tbl[1][4,4] );
  // __display("%x", HL16(tbl[1]).h );

  // #189 cases that should work, but produce a part-select chain
  //
  //      both are ok on Verilator 4.2 and Yosys 0.9+4081, Icarus rejects them
  __display("%x", HL16(data).h[4,4] );
  __display("%x", HL16(tbl[1]).l[4,4] );

}
