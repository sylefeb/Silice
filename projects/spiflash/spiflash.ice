// @sylefeb 2021
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice

algorithm spiflash_std(
  input  uint8 send,
  input  uint1 trigger,
  input  uint1 send_else_read,
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
    read      = (osc[0,1] ? {read[0,7],io1.i} : read);

    io0.o = sending[7,1];

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

algorithm spiflash_rom(
  input   uint1  in_ready,
  input   uint24 addr,
  output  uint8  rdata,
  output  uint1  busy(1),
  // QSPI flash
  output  uint1  sf_csn(1),
  output  uint1  sf_clk,
  inout   uint1  sf_io0,
  inout   uint1  sf_io1,
  inout   uint1  sf_io2,
  inout   uint1  sf_io3,
) <autorun> {

  uint1  trigger(0);
  uint1  init(1);
  uint24 raddr(24b000100010001000000000000); //_ 38h (QPI enable)

  spiflash_qspi spiflash(
    trigger <: trigger,
    clk     :> sf_clk,
    io0    <:> sf_io0,
    io1    <:> sf_io1,
    io2    <:> sf_io2,
    io3    <:> sf_io3,
  );

  uint11 wait(2047);
  uint3  three(0);
	uint3  stage(0);
	uint3  after(1);
  uint1  cmd_done(0);
  always {
		switch (stage)
		{
			case 0: {
  			stage = wait == 0 ? after : 0; // NOTE == 0 could be reduced (initial wait is wide)
        wait  = wait - 1;
			}
		  case 1: {
        three                   = 3b100;
				raddr                   = spiflash.qspi ? addr : raddr; // record address
        spiflash.send           = spiflash.qspi ? 8hEB : 8h00;  // command
        spiflash.send_else_read = 1;                            // sending
        // trigger                 = cmd_done; // trigger here if command sent
        // start sending?
				if (in_ready | ~spiflash.qspi) {
					busy                  = 1;
					sf_csn                = 0;
					stage                 = cmd_done ? 3 : 2;
          cmd_done              = spiflash.qspi;
				}
			}
      case 2: {
        trigger                 = 1;
				wait                    = 2; //_ 4 cycles
        after                   = 3;
				stage                   = 0;
      }
      case 3: {
        trigger                 = 1;
        spiflash.send           = raddr[16,8];
        raddr                   = raddr << 8;
				stage                   = 0; // wait
				wait                    = 2; //_ 4 cycles
        after                   = three[0,1] ? 4 : 3;
        three                   = three >> 1;
      }
      case 4: {
        sf_csn                  = ~spiflash.qspi; // not sending anything if in init
        trigger                 =  spiflash.qspi;
        // send dummy
        spiflash.send           = 8b00100000; // requests continuous read
				stage                   = 0; // wait
				wait                    = 1; //_ 3 cycles
        after                   = 5;
      }
      case 5: {
        spiflash.send_else_read = 0;
				stage                   = 0; // wait
				wait                    = 2; //_ 4 cycles
        after                   = 6;
      }
      case 6: {
        rdata                   = spiflash.read;
        sf_csn                  = 1;
        trigger                 = 0;
        busy                    = 0;
        spiflash.qspi           = 1; // qpi activated after first command
				stage                   = 1; // return to start stage
      }
		}
	}
}
