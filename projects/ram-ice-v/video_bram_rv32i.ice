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
  input  uint2  prepare,
  output uint10 xi,
  output uint1  intersects
) <autorun> {
$$if SIMULATION then
  uint16 cycle = 0;
  uint16 cycle_last = 0;
$$end

  uint1  in_edge  ::= ((y0 <= y && y1 >= y) || (y1 <= y && y0 >= y)) && (y0 != y1);
  uint10 last_y     = uninitialized;
  int20  xi_full    = uninitialized;

  intersects := in_edge;
  xi         := (y == y1) ? x1 : (xi_full >> 10);

 always {
$$if SIMULATION then
    cycle = cycle + 1;
$$end
 }

  while (1) {
    if (prepare[1,1]) {
      last_y  = y0 - 1;
      xi_full = x0 << 10;
  $$if SIMULATION then
      __display("prepared! (x0=%d y0=%d last_y=%d xi=%d interp=%d)",x0,y0,last_y,xi>>10,interp);
  $$end
    } else {
      if (y == last_y + 1) {
        xi_full = (xi_full + interp);
        last_y  = y;
  $$if SIMULATION then
  __display("  next [%d cycles] : y:%d interp:%d xi:%d it:%b)",cycle-cycle_last,y,interp,xi,intersects);
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
  output uint1  fbuffer = 0,
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
  uint32 data_override(0);

  // bram io
  bram_ram_32bits bram_ram(
    pram <:> mem,
    predicted_addr <: predicted_addr,
    data_override <: data_override
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
$$if SIMULATION then
   uint24 cycle = 0;
$$end
  // fun
  uint8   color = uninitialized;
  uint10  y     = uninitialized;
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
  uint10  xi0 = uninitialized;
  uint10  xi1 = uninitialized;
  uint10  xi2 = uninitialized;
  uint1   it0 = uninitialized;
  uint1   it1 = uninitialized;
  uint1   it2 = uninitialized;

  uint1   in_span = uninitialized;
  int11   span_x(-1);
  uint10  stop    = uninitialized;
  uint2   prepare(0);
  uint1   draw_triangle(0);
  uint1   wait_one(0);

  uint17 addr ::= span_x + (y << 9);


  edge_walk e0(
    x0 <:: x0, y0 <:: y0,
    x1 <:: x1, y1 <:: y1,
    interp  <:: ei0,
    prepare <:: prepare,
    y       <:: y,
    intersects   :> it0,
    xi           :> xi0,
    <:auto:>);

  edge_walk e1(
    x0 <:: x1, y0 <:: y1,
    x1 <:: x2, y1 <:: y2,
    interp  <:: ei1,
    prepare <:: prepare,
    y       <:: y,
    intersects   :> it1,
    xi           :> xi1,
    <:auto:>);

  edge_walk e2(
    x0 <:: x0, y0 <:: y0,
    x1 <:: x2, y1 <:: y2,
    interp  <:: ei2,
    prepare <:: prepare,
    y       <:: y,
    intersects :> it2,
    xi         :> xi2,
    <:auto:>);

  palette.wenable1     := 0;
  sdram.in_valid       := 0;
  sdram.rw             := 0;
  sd.in_valid          := 0;
  sd.rw                := 1;

  always {

    if (draw_triangle & ~wait_one) {      
      if (span_x[10,1]) {
        // find the span bounds, start drawing
        uint10 first  = uninitialized;
        uint10 second = uninitialized;
        uint1  nop = 0;
        __display("xi0:%d xi1:%d xi2:%d it0:%b it1:%b it2:%b",xi0,xi1,xi2,it0,it1,it2);
        switch (~{it2,it1,it0}) {
          case 3b001: { first = xi1; second = xi2; }
          case 3b010: { first = xi0; second = xi2; }
          case 3b100: { first = xi0; second = xi1; }
          case 3b000: { 
            if (xi0 == xi1) {
              first = xi0; second = xi2; 
            } else {
              first = xi0; second = xi1; 
            }
          }
          default:    { nop = 1; }
        }        
        if (first < second) {
          span_x = ~nop ? first : span_x;
          stop   = second;
        } else {
          span_x = ~nop ? second : span_x;
          stop   = first;        
        }
        sd.addr = 17h1FFFF;
        // __display("start span, x %d to %d, y %d",span_x,stop,y);
      } else {
        // write current to sdram
        if (sd.addr[0,17] != addr) {
          sd.addr     = {1b0,~fbuffer,7b0,addr};
          sd.in_valid = 1;
          sd.data_in  = color;
        //__display("write x %d y %d",span_x,y);
        } else {
          if (sd.done) {
            if (span_x == stop) {
              //__display("stop span, x %d y %d",span_x,y);
              y        = y + 1;
              span_x   = -1;
              wait_one = 1; // wait one cycle due to latency of edge walker
            } else {
              span_x = span_x + 1;
            }
          }
        }
      }
      draw_triangle = (y == ystop) ? 0 : 1;      
      //if (draw_triangle == 0) {
      //  __display("done");
      //}
    } else {// draw_triangle

      if (prepare[0,1]) {
        prepare       = {1b0,prepare[1,1]};
        draw_triangle = ~prepare[0,1];
      }
      wait_one = 0;

    }
  }

  while (1) {
    
    cpu_reset = 0;
    
    data_override = {{30{1b0}},vsync,draw_triangle};

    if (mem.in_valid & mem.rw) {
      switch (mem.addr[28,4]) {
        case 4b1000: {
          // __display("palette %h = %h",mem.addr[2,8],mem.data_in[0,24]);
          palette.addr1    = mem.addr[2,8];
          palette.wdata1   = mem.data_in[0,24];
          palette.wenable1 = 1;
        }
        case 4b0100: {
//          __display("SDRAM %h = %h",mem.addr[0,26],mem.data_in);
          sdram.data_in  = mem.data_in;
          sdram.wmask    = mem.wmask;
          sdram.addr     = mem.addr[0,26];
          sdram.rw       = 1;
          sdram.in_valid = 1;
        }
        case 4b0010: {
          switch (mem.addr[2,2]) {
            case 2b00: {
              //__display("LEDs = %h",mem.data_in[0,8]);
              leds = mem.data_in[0,8];
            }
            case 2b01: {
$$if SIMULATION then
              __display("swap buffers");
$$end                               
              fbuffer = ~fbuffer;
            }
            default: { }
          }
          //__display("data_override: %d",data_override);
        }
        case 4b0001: {
//          __display("(cycle %d) triangle (%b) = %d %d",cycle,mem.addr[2,5],mem.data_in[0,16],mem.data_in[16,16]);
          switch (mem.addr[2,7]) {
            case 7b0000001: { x0  = mem.data_in[0,16]; y0  = mem.data_in[16,16]; }
            case 7b0000010: { x1  = mem.data_in[0,16]; y1  = mem.data_in[16,16]; }
            case 7b0000100: { x2  = mem.data_in[0,16]; y2  = mem.data_in[16,16]; }
            case 7b0001000: { ei0 = mem.data_in; color = mem.data_in[24,8]; }
            case 7b0010000: { ei1 = mem.data_in; }
            case 7b0100000: { ei2 = mem.data_in; }
            case 7b1000000: { y = mem.data_in[0,16]; ystop = mem.data_in[16,16]; 
                              prepare = 2b11; draw_triangle = 0;
$$if SIMULATION then
                               __display("new triangle (color %d), cycle %d",color,cycle);
$$end                               
                               }
            default: { }
          }
        }
        default: { }
      }
    }
$$if SIMULATION then
    cycle = cycle + 1;
$$end    
  }
}

// ------------------------- 
