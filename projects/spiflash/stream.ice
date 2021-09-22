$$if ICARUS then
append('W25Q128JVxIM/W25Q128JVxIM.v')
import('simul_spiflash.v')
$$end

$$uart_in_clock_freq_mhz = 12
$include('../common/uart.ice')

$include('spiflash.ice')

circuitry wait3() // waits exactly 3 cycles
{
  uint2 n = 0; while (n != 1) { n = n + 1; }
}

circuitry wait4() // waits exactly 4 cycles
{
  uint2 n = 0; while (n != 2) { n = n + 1; }
}

circuitry wait24() // waits exactly 24 cycles
{
  uint5 n = 0; while (n != 22) { n = n + 1; }
}

algorithm spiflash_rom(
  input   uint1  in_ready,
  input   uint24 addr,
  output! uint8  rdata,
  output  uint1  busy(1),
  // QSPI flash
  output  uint1  sf_csn,
  output  uint1  sf_clk,
  inout   uint1  sf_io0,
  inout   uint1  sf_io1,
  inout   uint1  sf_io2,
  inout   uint1  sf_io3,
) <autorun> {

  uint1 trigger(0);
  spiflash_qspi spiflash(
    trigger <: trigger,
    clk     :> sf_clk,
    io0    <:> sf_io0,
    io1    <:> sf_io1,
    io2    <:> sf_io2,
    io3    <:> sf_io3,
  );

  // ===== init: enter QPI
  //_ 8h38 is 8b00111000 (enter QPI)
  // send command
  spiflash.qspi           = 0; // not qpi yet
  // send command two bits at a time
  spiflash.send           = 8b00000000;
  //                             ^   ^
  spiflash.send_else_read = 1; // sending
  sf_csn                  = 0;
++:  /*needed*/                         // we trigger spiflash commuincation
  trigger                 = 1; // maintain until done
  () = wait4();
  spiflash.send           = 8b00010001;
  () = wait4();
  spiflash.send           = 8b00010000;
  () = wait4();
  spiflash.send           = 8b00000000;
  () = wait4();
  // done
  sf_csn                  = 1;
  trigger                 = 0;
  spiflash.qspi           = 1; // qspi enabled
++:
  busy = 0;

  // answer requests
  while (1) {
    if (in_ready) {
      // send command
      spiflash.send           = 8hEB;
      spiflash.send_else_read = 1; // sending
      sf_csn                  = 0;
++:
      trigger                 = 1;
      () = wait4();
      // send address
      spiflash.send           = addr[16,8];
      () = wait4();
      spiflash.send           = addr[ 8,8];
      () = wait4();
      spiflash.send           = addr[ 0,8];
      () = wait4();
      // send dummy
      spiflash.send           = 8h00;
++:
++:
++:
      spiflash.send_else_read = 0;
      ()    = wait4();
      rdata                   = spiflash.read;
      sf_csn                  = 1;
      trigger                 = 0;
    }
  }

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

  uart_out uo;
$$if UART then
  uart_sender usend(
    io      <:> uo,
    uart_tx :>  uart_tx
  );
$$end

spiflash_rom sf_rom(
    sf_clk :>  sf_clk,
    sf_csn :>  sf_csn,
    sf_io0 <:> sf_io0,
    sf_io1 <:> sf_io1,
    sf_io2 <:> sf_io2,
    sf_io3 <:> sf_io3,
  );

  always {
    uo.data_in_ready = 0;
    sf_rom.in_ready  = 0;
$$if SIMULATION then
    cycle = cycle + 1;
$$end
  }

  while (sf_rom.busy) { }

  // read some
  data.wenable            = 1;
  while (data.addr != 64) {
    sf_rom.in_ready = 1;
    sf_rom.addr     = data.addr;
    ()              = wait24();
// ++:
    __display("read %x",sf_rom.rdata);
    data.wdata      = sf_rom.rdata;
    data.addr       = data.addr + 1;
  }

  // output to UART
  data.wenable = 0;
  data.addr    = 1;
  while (data.addr != 64) {
    uo.data_in       = data.rdata;
    uo.data_in_ready = 1;
    data.addr        = data.addr + 1;
    while (uo.busy) { }
  }

}
