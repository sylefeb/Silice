// SL 2020-12-02 @sylefeb
// ------------------------- 

$$if SIMULATION then
$$verbose = nil
$$end

// pre-compilation script, embeds compile code within sdcard image
$$dofile('pre_include_asm.lua')
$$if not SIMULATION then
$$  init_data_bytes = math.max(init_data_bytes,(1<<21)) -- we load 2 MB to be sure we can append stuff
$$end

// default palette
$$palette = {}
$$for i=1,256 do
$$  palette[i] = (i) | (((i<<1)&255)<<8) | (((i<<2)&255)<<16)
$$end
$$ palette[256] = 255 | (255<<8) | (255<<16)

$$if SIMULATION then
$$  frame_drawer_at_sdram_speed = true
$$else
$$  fast_compute = true
$$end

$include('../common/video_sdram_main.ice')

$include('ram-ice-v.ice')
$include('bram_ram_32bits.ice')
$include('sdram_ram_32bits.ice')

// ------------------------- 

algorithm edge_walk(
  input  uint10  y,
  input  uint10 x0,
  input  uint10 y0,
  input  uint10 x1,
  input  uint10 y1,
  input  int20  interp,
  input  uint1  prepare,
  output int20  xi,
  output uint1  intersects
) <autorun> {
$$if SIMULATION then
  uint16 cycle = 0;
  uint16 cycle_last = 0;
$$end

  uint1  in_edge  ::= (y0 < y && y1 >= y) || (y1 < y && y0 >= y);
  uint10 last_y     = uninitialized;

  intersects := in_edge;

 always {
$$if SIMULATION then
    cycle = cycle + 1;
$$end
 }

  while (1) {
    if (prepare) {
      last_y = y0;
      xi     = x0 << 10;
      __display("prepared! (x0=%d y0=%d xi=%d interp=%d)",x0,y0,xi>>10,interp);
    } else {
       // __display("[%d cycles] y %d last_y %d",cycle-cycle_last,y,last_y);
      if (y == last_y + 1) {
        xi     = xi + interp;
        last_y = y;
  $$if SIMULATION then
  __display("  next [%d cycles] : y:%d interp:%d xi:%d)",cycle-cycle_last,y,interp,xi>>10);
  $$end
      }
    }
  }
}

// ------------------------- 

algorithm frame_drawer(
  sdram_user    sd,
  sdram_user    sda,
  input  uint1  sdram_clock,
  input  uint1  sdram_reset,
  input  uint1  vsync,
  output uint1  fbuffer,
  output uint8  leds,
  simple_dualport_bram_port1 palette,
) <autorun> {

  rv32i_ram_io sdram;
  // sdram io
  sdram_ram_32bits bridge<@sdram_clock,!sdram_reset>(
    sdr <:> sda,
    r32 <:> sdram,
  );

  rv32i_ram_io mem;
  uint26 predicted_addr = uninitialized;

  // bram io
  bram_ram_32bits bram_ram(
    pram <:> mem,
    predicted_addr <: predicted_addr,
  );

  uint1  cpu_reset      = 1;
  uint26 cpu_start_addr = 26h0000000;
  uint3  cpu_id         = 0;
  
  // cpu 
  rv32i_cpu cpu<!cpu_reset>(
    boot_at  <:  cpu_start_addr,
    predicted_addr :> predicted_addr,
    cpu_id   <:  cpu_id,
    ram      <:> mem
  );

 uint24 cycle = 0;

  // fun
  uint10  y  = uninitialized;
  uint10  ystop = uninitialized;
  uint10  x0  = uninitialized;
  uint10  y0  = uninitialized;
  uint10  x1  = uninitialized;
  uint10  y1  = uninitialized;
  uint10  x2  = uninitialized;
  uint10  y2  = uninitialized;
  int20   ei0 = uninitialized;
  int20   ei1 = uninitialized;
  int20   ei2 = uninitialized;
  int20   xi0 = uninitialized;
  int20   xi1 = uninitialized;
  int20   xi2 = uninitialized;
  uint1   it0 = uninitialized;
  uint1   it1 = uninitialized;
  uint1   it2 = uninitialized;

  uint1   in_span = uninitialized;
  int11   span_x(-1);
  uint10  start   = uninitialized;
  uint10  stop    = uninitialized;
  uint1   prepare(0);
  uint1   draw_triangle(0);

  uint17 addr ::= span_x + (y << 9);


  edge_walk e0(
    x0 <:: x0, y0 <:: y0,
    x1 <:: x1, y1 <:: y1,
    interp  <:: ei0,
    prepare <: prepare,
    y       <: y,
    intersects   :> it0,
    xi           :> xi0,
    <:auto:>);

  edge_walk e1(
    x0 <:: x1, y0 <:: y1,
    x1 <:: x2, y1 <:: y2,
    interp  <:: ei1,
    prepare <: prepare,
    y       <: y,
    intersects   :> it1,
    xi           :> xi1,
    <:auto:>);

  edge_walk e2(
    x0 <:: x0, y0 <:: y0,
    x1 <:: x2, y1 <:: y2,
    interp  <:: ei2,
    prepare <: prepare,
    y       <: y,
    intersects :> it2,
    xi         :> xi2,
    <:auto:>);

  fbuffer              := 0;
  palette.wenable1     := 0;
  sdram.in_valid       := 0;
  sd.in_valid          := 0;
  sd.rw                := 1;

  always {

    if (draw_triangle) {
      // find the span bounds
      uint10 first  = uninitialized;
      uint10 second = uninitialized;
      uint1  skip   = 0;
      switch (~{it2,it1,it0}) {
        case 3b001: {first = xi1>>10; second = xi2>>10; }
        case 3b010: {first = xi0>>10; second = xi2>>10; }
        case 3b100: {first = xi0>>10; second = xi1>>10; }
        default: { skip = 1; }
      }
      if (first < second) {
        start = first;
        stop  = second;
      } else {
        start = second;
        stop  = first;        
      }
      if (!skip) {
        // __display("span %d [%d-%d] %b %b %b",y,start,stop,it0,it1,it2);      
        if (span_x[10,1]) {
          // start drawing span
          span_x  = start;
          sd.addr = 17h1FFFF;
          __display("start span, x %d y %d",span_x,y);
        } else {
          // write current to sdram
          if (sd.addr != addr) {
            sd.addr     = addr;
            sd.in_valid = 1;
            sd.data_in  = 255;
          __display("write x %d y %d",span_x,y);
          } else {
            if (sd.done) {
              if (span_x == stop) {
          __display("stop span, x %d y %d",span_x,y);
                y      = y + 1;
                span_x = -1;
              } else {
                span_x = span_x + 1;
              }
            }
          }
        }
      } else {
        y = y + 1;
      }
      draw_triangle = (y == ystop) ? 0 : 1;
    } // draw_triangle

    if (prepare) {
      draw_triangle = 1;
      prepare = 0;
    }
  }

  while (1) {
    cpu_reset = 0;

    if (mem.in_valid & mem.rw) {
      switch (mem.addr[28,4]) {
        case 4b1000: {
          // __display("palette %h = %h",mem.addr[2,8],mem.data_in[0,24]);
          palette.addr1    = mem.addr[2,8];
          palette.wdata1   = mem.data_in[0,24];
          palette.wenable1 = 1;
        }
        case 4b0100: {
          // __display("SDRAM %h = %h",mem.addr[0,26],mem.data_in);
          sdram.data_in  = mem.data_in;
          sdram.wmask    = mem.wmask;
          sdram.addr     = mem.addr[0,26];
          sdram.rw       = 1;
          sdram.in_valid = 1;
        }
        case 4b0010: {
          __display("LEDs = %h",mem.data_in[0,8]);
          leds = mem.data_in[0,8];
        }
        case 4b0001: {
          __display("(cycle %d) triangle (%b) = %d %d",cycle,mem.addr[2,5],mem.data_in[0,16],mem.data_in[16,16]);
          switch (mem.addr[2,7]) {
            case 7b0000001: { x0  = mem.data_in[0,16]; y0  = mem.data_in[16,16]; }
            case 7b0000010: { x1  = mem.data_in[0,16]; y1  = mem.data_in[16,16]; }
            case 7b0000100: { x2  = mem.data_in[0,16]; y2  = mem.data_in[16,16]; }
            case 7b0001000: { ei0 = mem.data_in; }
            case 7b0010000: { ei1 = mem.data_in; }
            case 7b0100000: { ei2 = mem.data_in; }
            case 7b1000000: { y = mem.data_in[0,16]; ystop = mem.data_in[16,16]; 
                              prepare = 1; draw_triangle = 0; }
            default: { }
          }
        }
        default: { }
      }
    }

cycle = cycle + 1;
  }
}

// ------------------------- 
