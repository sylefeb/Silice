// SL @sylefeb 2020-08
//
// Simple SDcard controller
// only supports SDHC/SDXC
//
// Stays in slow xfer mode
//
// Timings for   25 MHz
// Tested ok at  50 MHz
// Tested ok at 100 MHz
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

group sdcardio {
  uint32 addr_sector = 0,
  uint1  read_sector = 0,
  uint1  ready       = 0,
}

interface sdcardio_ctrl {
  input!  addr_sector,
  input!  read_sector,
  output  ready,
}

algorithm sdcard(
  output  uint1  sd_clk,
  output  uint1  sd_mosi,
  output  uint1  sd_csn,
  input   uint1  sd_miso,
  // read io
  sdcardio_ctrl  io,
  // storage
  simple_dualbram_port1 store
) <autorun> {
  
  // assert(sizeof(io.addr_sector) == 32);
  
  subroutine send(
    input  uint48   cmd,
    readwrites      sd_clk,
    writes          sd_mosi
  ) {
    uint16 count = 0;
    uint48 shift = uninitialized;
    shift        = cmd;
    while (count < $2*256*48$) { // 48 clock pulses @~400 kHz (assumes 50 MHz clock)
      if ((count&255) == 255) {      
        sd_clk  = ~sd_clk;
        if (!sd_clk) {
          sd_mosi = shift[47,1];
          shift   = {shift[0,47],1b0};
        }
      }
      count = count + 1;
    }
    sd_mosi = 1;
  }
  
  subroutine read(
    input  uint6    len,
    input  uint1    wait,
    output uint40   answer,
    input  uint8    rate,
    readwrites      sd_clk,
    writes          sd_mosi,
    reads           sd_miso
  ) {  
    uint16 count = 0;
    uint6  n     = 0;
    answer       = 40hffffffffff;
    while ( // will only stop on sd_clk == 0
      (wait && answer[len-1,1]) || ((!wait) && n < len)
    ) { // read answer
      if ((count&rate) == rate) { // swap clock
        sd_clk  = ~sd_clk;
        if (!sd_clk) {
          n       = n + 1;
          answer  = {answer[0,39],sd_miso};
        }
      }
      count = count + 1;      
    }
  }
  
  uint24 count  = 0;
  uint40 status = 0;
  uint48 cmd0   = 48b010000000000000000000000000000000000000010010101;
  uint48 cmd8   = 48b010010000000000000000000000000011010101010000111;
  uint48 cmd55  = 48b011101110000000000000000000000000000000000000001;
  uint48 acmd41 = 48b011010010100000000000000000000000000000000000001;
  uint48 cmd16  = 48b010100000000000000000000000000100000000000010101;
  uint48 cmd17  = 48b010100010000000000000000000000000000000001010101;
  //                 01ccccccaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaarrrrrrr1
  
  uint1  do_read_sector = 0;
  uint32 do_addr_sector = 0;
  
  store.wenable1 := 1; // writes
  
  always {
    
    if (io.read_sector) {
      do_read_sector = 1;
      do_addr_sector = io.addr_sector;
      io.ready = 0;
    }
 
  }
  
  sd_mosi = 1;
  sd_csn  = 1;
  sd_clk  = 0;

  // wait 2 msec (power up), @50 MHz
  count = 0;
  while (count < 100000) { count = count + 1; }
  
  // request SPI mode  
  count   = 0;
  while (count < $2*256*80$) { // 74+ clock pulses @~400 kHz (assumes 50 MHz clock)
    if ((count&255) == 255) {
      sd_clk = ~sd_clk;
    }
    count = count + 1;
  }

  sd_csn         = 0; 
  store.addr1    = 0;
  
  // init
  () <- send <- (cmd0);
  (status) <- read <- (8,1,255);
  
  () <- send <- (cmd8);
  (status) <- read <- (40,1,255);

  while (1) {
    () <- send <- (cmd55);
    (status) <- read <- (8,1,255);
    () <- send <- (acmd41);
    (status) <- read <- (8,1,255);
    if (status[0,8] == 0) {
      break;
    }
  }

  () <- send <- (cmd16);
  (status) <- read <- (8,1,255);

  io.ready = 1;  
  
  // ready to work
  while (1) {
    
    if (do_read_sector) {
      do_read_sector = 0;

      // read some!
      () <- send <- ({cmd17[40,8],do_addr_sector,cmd17[0,8]});

      (status) <- read <- (8,1,3); // response

      if (status[0,8] == 8h00) {
        (status) <- read <- (1,1,3); // start token
        
        store.addr1 = 0;
        (store.wdata1) <- read <- (8,0,3); // bytes  
        while (store.addr1 < 511) {
          (store.wdata1) <- read <- (8,0,3); // bytes          
          store.addr1 = store.addr1 + 1;
        }        
        (status) <- read <- (16,1,3); // CRC
        
        io.ready = 1;

      } else {
      
        io.ready = 1;

      }
    }
    
  }
  
}

// ------------------------- 
