algorithm spiflash_std(
  input  uint8 send,
  input  uint1 trigger,
  input  uint1 send_else_read,
  output uint8 read,
  output uint1 clk,
  //output uint1 io0,
  //input  uint1 io1,
  inout  uint1 io0,
  inout  uint1 io1,
  inout  uint1 io2,
  inout  uint1 io3,
) {
  uint2 osc(0);
  uint1 dc(0);
  uint8 sending(0);
  uint8 busy(0);

  always {
    io0.oenable = 1;  io1.oenable = 0; // DO, DI
    io2.oenable = 1;  io2.o       = 1;
    io3.oenable = 1;  io3.o       = 1;
    osc     = trigger ? {osc[0,1],osc[1,1]} : 2b10;
    clk     = trigger & osc[0,1]; // SPI Mode 0
    sending   = busy[0,1] ? (osc[0,1] ? {sending[0,7],1b0} : sending) : (
                  trigger ? send
                          : sending );
    busy      = busy[0,1] ? (osc[0,1] ? {1b0,   busy[1,7]} : busy) : (
                trigger   ? 8b11111111
                          : busy );
    read      = (osc[0,1] ? {read[0,7],io1.i/*io1*/} : read);

    /*io0*/ io0.o = sending[7,1];

  }
}

algorithm spiflash_qspi(
  input  uint8 send,
  input  uint1 trigger,
  input  uint1 send_else_read,
  input  uint1 qspi,
  output uint8 read,
  output uint1 clk,
  inout  uint1 io0,
  inout  uint1 io1,
  inout  uint1 io2,
  inout  uint1 io3,
) {
  uint2 osc(0);
  uint1 dc(0);
  uint8 sending(0);
  uint2 busy(0);

  always {
    io0.oenable = send_else_read;
    io1.oenable = send_else_read & qspi;
    io2.oenable = send_else_read & qspi;
    io3.oenable = send_else_read & qspi;

    osc       = trigger ? {osc[0,1],osc[1,1]} : 2b10;
    clk       = trigger & osc[0,1]; // SPI Mode 0

    busy      =  busy[0,1] ? (osc[0,1] ? {1b0,   busy[1,1]} : busy) : (
                 trigger   ? 8b11
                           : busy );
    sending   = ~busy[0,1] ? send : sending;
    read      = (osc[0,1] ? {read[0,4],io3.i,io2.i,io1.i,io0.i} : read);

    io0.o     = busy == 2b01 ? sending[0,1] : sending[4,1];
    io1.o     = busy == 2b01 ? sending[1,1] : sending[5,1];
    io2.o     = busy == 2b01 ? sending[2,1] : sending[6,1];
    io3.o     = busy == 2b01 ? sending[3,1] : sending[7,1];
  }
}
