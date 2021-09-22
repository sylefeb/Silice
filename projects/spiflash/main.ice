$$if ICARUS then
append('W25Q128JVxIM/W25Q128JVxIM.v')
import('simul_spiflash.v')
$$end

$$uart_in_clock_freq_mhz = 12
$include('../common/uart.ice')

algorithm spiflash_std(
  input  uint8 send,
  input  uint1 trigger,
  input  uint1 send_else_read,
  output uint8 read,
  output uint1 clk,
  output uint1 io0,
  input  uint1 io1,
  //inout  uint1 io0,
  //inout  uint1 io1,
  //inout  uint1 io2,
  //inout  uint1 io3,
) {
  uint2 osc(0);
  uint1 dc(0);
  uint8 sending(0);
  uint8 busy(0);

  always {
    //io0.oenable = 1;  io1.oenable = send_else_read; // DO, DI
    //io2.oenable = 1;  io2.o       = 1;
    //io3.oenable = 1;  io3.o       = 1;
    osc     = trigger ? {osc[0,1],osc[1,1]} : 2b10;
    clk     = trigger & osc[0,1]; // SPI Mode 0
    sending   = busy[0,1] ? (osc[0,1] ? {sending[0,7],1b0} : sending) : (
                  trigger ? send
                          : sending );
    busy      = busy[0,1] ? (osc[0,1] ? {1b0,   busy[1,7]} : busy) : (
                trigger   ? 8b11111111
                          : busy );
    read      = (osc[0,1] ? {read[0,7],/*io1.i*/io1} : read);

    io0 /*io0.o*/     = /*~send_else_read |*/ sending[7,1];
    //                  ^^^^^ required? RECHECK

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

circuitry wait16() // waits exactly 16 cycles
{
  uint5 n = 0; while (n != 14) { n = n + 1; }
}

circuitry wait3() // waits exactly 3 cycles
{
  uint2 n = 0; while (n != 1) { n = n + 1; }
}

circuitry wait4() // waits exactly 4 cycles
{
  uint2 n = 0; while (n != 2) { n = n + 1; }
}

circuitry wait8() // waits exactly 8 cycles
{
  uint3 n = 0; while (n != 6) { n = n + 1; }
}

algorithm main(
  output uint8 leds,
$$if QSPIFLASH then
  output uint1 sf_clk,
  output uint1 sf_csn,
  inout  uint1 sf_io0,
  inout  uint1 sf_io1,
  inout  uint1 sf_io2,
  inout  uint1 sf_io3,
$$end
$$if SPIFLASH then
  output uint1 sf_clk,
  output uint1 sf_csn,
  output uint1 sf_mosi,
  input  uint1 sf_miso,
$$end
$$if UART then
  output uint1 uart_tx,
  input  uint1 uart_rx,
$$end
  )
{

$$if SIMULATION then
  uint1 sf_csn(1);
  uint1 sf_clk(0);
  uint1 sf_io0(0);
  uint1 sf_io1(0);
  uint1 sf_io2(0);
  uint1 sf_io3(0);
$$if ICARUS then
  simul_spiflash simu(
    CSn <:  sf_csn,
    CLK <:  sf_clk,
    IO0 <:> sf_io0,
    IO1 <:> sf_io1,
    IO2 <:> sf_io2,
    IO3 <:> sf_io3,
  );
$$end
  uint32 cycle(0);
$$end

  bram uint8 data[256] = uninitialized;

  uint1 trigger(0);
  uint9 iter(0);

$$STANDARD = 1
$$QSPI     = nil

$$if STANDARD then

  uart_out uo;
$$if UART then
  uart_sender usend(
    io      <:> uo,
    uart_tx :>  uart_tx
  );
$$end

  spiflash_std spiflash(
    trigger <: trigger,
    clk :>  sf_clk,
    io0 :>  sf_mosi,
    io1 <:  sf_miso,
    //io0 <:> sf_io0,
    //io1 <:> sf_io1,
    //io2 <:> sf_io2,
    //io3 <:> sf_io3,
  );

  always {
    // sf_csn           = reset;
    uo.data_in_ready = 0;
$$if SIMULATION then
    cycle            = cycle + 1;
$$end
  }

  () = wait16();
  spiflash.send_else_read = 1; // sending

  sf_csn  = 0;
//++:
/*
  spiflash.send    = 8hAB; // command
  trigger = 1;             // maintain until done
  () = wait16();
  trigger = 0;
++:
  sf_csn  = 1;
++:
() = wait16();
  sf_csn  = 0;
++:
*/
//++:
  spiflash.send    = 8h03; // command
  trigger = 1;             // maintain until done
  () = wait16();
  spiflash.send    = 8h00; // addr 0
  () = wait16();
  spiflash.send    = 8h00; // addr 1
  () = wait16();
  spiflash.send    = 8h00; // addr 2
  () = wait16();
  spiflash.send_else_read = 0; // reading
  // read some
  data.wenable     = 1;
  () = wait16();
  while (data.addr != 255) {
    data.wdata       = spiflash.read;
    data.addr        = data.addr + 1;
    ()               = wait16();
  }
  // output to UART
  data.wenable = 0;
  data.addr    = 1;
  while (data.addr != 255) {
$$if SIMULATION then
    __display("cycle %d] read %x",cycle,data.rdata);
    if (data.addr == 4) { __finish(); }
$$end
    uo.data_in       = data.rdata;
    uo.data_in_ready = 1;
    data.addr        = data.addr + 1;
    while (uo.busy) { }
  }

$$end

$$if QSPI then

  uart_out uo;
$$if UART then
  uart_sender usend(
    io      <:> uo,
    uart_tx :>  uart_tx
  );
$$end

  spiflash_qspi spiflash(
    trigger <: trigger,
    clk :>  sf_clk,
    io0 <:> sf_io0,
    io1 <:> sf_io1,
    io2 <:> sf_io2,
    io3 <:> sf_io3,
  );

  always {
    sf_csn   = reset;
    uo.data_in_ready = 0;
$$if SIMULATION then
    cycle = cycle + 1;
$$end
  }
  // send command
  spiflash.qspi           = 0; // not qspi
  spiflash.send_else_read = 1; // sending
  //_ 8hEB is 8b11101011
  //  we send this over qspi, two bits at a time to initialize the read
  spiflash.send           = 8b00010001; // what to sent is set one cycle before
++:                                     // we trigger spiflash commuincation
  trigger                 = 1; // maintain until done
  () = wait3();           // wait 3 cycles, we send 1 cycle in advance
  spiflash.send           = 8b00010000;
  () = wait4();
  spiflash.send           = 8b00010000;
  () = wait4();
  spiflash.send           = 8b00010001;
  () = wait4();

  // send address
  spiflash.send           = 8h00;
  spiflash.qspi           = 1; // enable qspi
  () = wait4();
  spiflash.send           = 8h00;
  () = wait4();
  spiflash.send           = 8h00;
  () = wait4();
  // send mode
  spiflash.send           = 8h00;
  () = wait4();
  // send dummy
  spiflash.send           = 8h00;
  () = wait4();
  spiflash.send           = 8h00;
  () = wait4();

  // read (finally ...)
  spiflash.send_else_read = 0;
  () = wait4();
  // stream to uart
  while (iter != 255) {
$$if SIMULATION then
    __display("cycle %d] read %x",cycle,spiflash.read);
    if (iter == 4) { __finish(); }
$$end
    uo.data_in       = spiflash.read;
    uo.data_in_ready = 1;
    iter             = iter + 1;
    ()               = wait4();
  }

$$end

}
