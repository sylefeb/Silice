// SL 2020-07-13
// Wave function collapse (with image output)
//
// Scanline version, non toroidal grid
// --
// Special case version than does not require 
// propagation beyond the currently visited site
// Only possible if non-toroidal
// --

$$if ICESTICK then
$$GX = 16
$$GY = 16
$$else
// full screen 640x480
$$GX = 40
$$GY = 30
$$end

$include('../common/empty.ice')
$include('../vga_demo/vga_demo_main.ice')

$$PROBLEM = 'problems/paths/'
$$dofile('pre_rules.lua')

// -------------------------
// rule-processor
// applies the neighboring rules

algorithm wfc_rule_processor(
  input   uint$L$ site,
  input   uint$L$ left,   // -1, 0
  input   uint$L$ right,  //  1, 0
  input   uint$L$ top,    //  0,-1
  input   uint$L$ bottom, //  0, 1
  output! uint$L$ newsite,
  output! uint1   nstable
) {
  always {
    newsite = site & (
$$for i=1,L do
      ({$L${left[$i-1$,1]}} & $L$b$Rleft[i]$)
$$if i < L then
    |
$$end      
$$end
    ) & (
$$for i=1,L do
      ({$L${right[$i-1$,1]}} & $L$b$Rright[i]$)
$$if i < L then
    |
$$end      
$$end
    ) & (
$$for i=1,L do
      ({$L${top[$i-1$,1]}} & $L$b$Rtop[i]$)
$$if i < L then
    |
$$end      
$$end
    ) & (
$$for i=1,L do
      ({$L${bottom[$i-1$,1]}} & $L$b$Rbottom[i]$)
$$if i < L then
    |
$$end      
$$end
    )    
    ;
    nstable = (newsite != site);
  }
}

// -------------------------
// produce a vector of '1' for init with all labels

$$ones='' .. L .. 'b'
$$for i=1,L do
$$ ones = ones .. '1'
$$end

// -------------------------
// helper function to generate random permutation table

$$function permute_table(n)
$$tab={}
$$for i = 0,n-1 do
$$  tab[i] = i
$$end
$$for i = 0,n-1 do
$$  local j = math.random(i, n-1)
$$  tab[i], tab[j] = tab[j], tab[i]
$$end
$$return tab
$$end

// -------------------------
// algorithm to make a choice
// this is akin to a reduction
// - each bit proposes its rank
// - when two are present, one is randomly selected
algorithm makeAChoice(
  input   uint$L$ i,
  input   uint16  rand,
  output! uint$L$ o)
{

$$L_pow2=0
$$tmp = L
$$while tmp > 1 do
$$  L_pow2 = L_pow2 + 1
$$  tmp = (tmp/2)
$$end
$$print('choice reducer has ' .. L_pow2 .. ' levels')

$$nr = 0
$$for lvl=L_pow2-1,0,-1 do
$$  for i=0,(1<<lvl)-1 do
  uint5 keep_$lvl$_$2*i$_$2*i+1$ := 
$$    if lvl == L_pow2-1 then
$$      if 2*i < L then
$$        if 2*i+1 < L then
            (i[$2*i$,1] && i[$2*i+1$,1]) ? (rand[$nr$,1] ? $2*i$ : $2*i+1$) : (i[$2*i$,1] ? $2*i$ : (i[$2*i+1$,1] ? $2*i+1$ : 0)) ;
$$        else
            (i[$2*i$,1] ? $2*i$ : 0) ;
$$        end
$$      else
           0;
$$      end
$$    else
           (keep_$lvl+1$_$4*i$_$4*i+1$ && keep_$lvl+1$_$4*i+2$_$4*i+3$) ? (rand[$nr$,1] ? keep_$lvl+1$_$4*i$_$4*i+1$ : keep_$lvl+1$_$4*i+2$_$4*i+3$) : (keep_$lvl+1$_$4*i$_$4*i+1$ | keep_$lvl+1$_$4*i+2$_$4*i+3$);
$$    end
$$    nr = nr + 1
$$    if nr > 15 then nr = 0 end
$$  end
$$end

  o := (1<<keep_0_0_1);

}

// -------------------------
// pll
$$if ULX3S then
import('../common/ulx3s_clk_50_25.v')
$$end 

$$if ICARUS then
import('../common/simul_clk_166.v')
$$end

// -------------------------
// main WFC algorithm
// scans increasing i then increasing j
// rewrite the entire domain, starting from scratch

algorithm wfc(
  output! uint1   we,
  output! uint16  addr,
  output! uint$L$ data_out,
  input   uint16  offset,
  input   uint16  seed,
  input   uint1   wfc_run
) <autorun> {

  // site being considered
  uint$L$ site       = uninitialized;
  // neighboring sites on the sides
  uint$L$ left       = $ones$;
  uint$L$ right      = $ones$;
  // neighboring site below
  uint$L$ btm        = uninitialized; // just below
  // sites above
  uint$L$ above       = $ones$;
  uint$L$ newabove    = $ones$;
  uint$L$ above_left  = $ones$;
  uint$L$ above_right = $ones$;
  uint$L$ prev_choice = uninitialized;
  
  // rule-processors
  uint1   nstable1   = 0; // not used
  uint1   nstable2   = 0; // not used
  uint$L$ newsite    = uninitialized;
  uint$L$ ones       = $ones$;
  
  wfc_rule_processor proc1(
    site    <:: site,
    left    <:: left,
    right   <:: right,
    top     <:: ones,  // unconstrained (scanline bottom to top)
    bottom  <:: btm,
    newsite :>  newsite,
    nstable :>  nstable1
  );

  wfc_rule_processor proc2(
    site    <:: ones,   // unconstrained
    left    <:: above_left,
    right   <:: above_right,
    top     <:: ones,   // unconstrained (scanline bottom to top)
    bottom  <:: prev_choice,
    newsite :>  newabove,
    nstable :>  nstable2
  );

  // algorithm for choosing a label
  uint$L$ choice = uninitialized;
  makeAChoice chooser(
    i    <:: site,
    rand <:: rand,
    o    :>  choice
  );

  // bram for previous row
  // NOTE: can't do in domain to allow for proper
  //       synthesis of multiport domain bram as
  //       port0 read only and port1 write only
  bram uint$L$ previous_row[$GX$] = {
$$for n=1,GX do
    $ones$,
$$end
  };
  // bram for current row with backward rules applied
  bram uint$L$ current_row[$GX$] = {
$$for n=1,GX do
    $ones$,
$$end
  };
  
  // brom with permutation table (random generator)
$$ptblA = permute_table(256)
$$ptblB = permute_table(256)
  uint16 permut[256] = {
$$for n=0,255 do
    $ptblA[n] | (ptblB[n] << 8)$,
$$end
  };
  uint8 permut_addr = 0;
  
  // random
  uint16 rand = 0;    

  // write result
  we := 1;
  
  while (1) {
  
    while (wfc_run == 0) { }
  
    permut_addr = seed;

    __display("wfc start");

    // scan through grid, zig-zag
    // => we are reading/writing in previous row
    //    while processing current site
    {
      uint1  dir        = 1;
      uint16 j          = 0;
      while (j < $GX*GY$) {
        int16 prev_i      = uninitialized;
        int16 i           = uninitialized;
        int16 next_i      = uninitialized;
        int16 next_next_i = uninitialized;
        prev_i      = dir ? -3 : $GX$+2;
        i           = dir ? -2 : $GX$+1;
        next_i      = dir ? -1 : $GX$;
        next_next_i = dir ?  0 : $GX$-1;
        site        = $ones$;
        left        = $ones$;
        right       = $ones$;
        above_left  = $ones$;
        above_right = $ones$;
        while (dir ? prev_i < $GX$ : prev_i >= 0) { 
          // rules have been applied at i,j
          // -> start making a choice at i,j
          rand        = permut[permut_addr];
          site        = newsite;
          // -> next random
          permut_addr = (permut_addr + 1);
          // -> meanwhile read next btm from previous
          previous_row.wenable = 0;
          previous_row.addr    = next_i;
          // -> meanwhile read next next from current
          current_row.wenable  = 0;
          current_row.addr     = next_next_i;
          // -> start applying rules above
          if (dir) {
            above_right = above;
            above_left  = ones;
          } else {
            above_right = ones;
            above_left  = above;
          }
  ++:        
          // choice has been made at i,j
          // -> write result
          addr       = i + j;
          data_out   = choice;
          // -> store in previous for next row
          previous_row.wenable = 1;
          previous_row.wdata   = choice;
          previous_row.addr    = i;
          // move known sites to start appyling rule on next
          btm            = (j > 0 && next_i >=0 && next_i < $GX$) ? previous_row.rdata : ones;
          if (dir) {
            right        = choice;
            site         = left;
            left         = (next_next_i >=0 && next_next_i < $GX$) ? current_row.rdata : ones;
          } else {
            left         = choice;
            site         = right;
            right        = (next_next_i >=0 && next_next_i < $GX$) ? current_row.rdata : ones;
          }
          // rules have been applied above
          above               = newabove;
          // -> store in current for next row
          current_row.wenable = 1;
          current_row.wdata   = newabove;
          current_row.addr    = prev_i;
          // -> record choice for appyling rules above
          prev_choice  = choice;
          // next
          prev_i       = i;
          i            = next_i;
          next_i       = next_next_i;
          next_next_i  = next_next_i + (dir ? 1 : -1);
        }
        dir        = ~ dir; // reverse direction
        j          = j + $GX$;
      }
    }

    __display("wfc done");  
    
  }
  
}

// -------------------------

algorithm frame_display(
  input   uint10 pix_x,
  input   uint10 pix_y,
  input   uint1  pix_active,
  input   uint1  pix_vblank,
$$if DE10NANO then
  output uint4  kpadC,
  input  uint4  kpadR,
$$end
$$if ULX3S then
  input  uint7 btn,
$$end
  output! uint$color_depth$ pix_r,
  output! uint$color_depth$ pix_g,
  output! uint$color_depth$ pix_b
) <autorun> {

$$if ULX3S then
  // on the ULX3S we run WFC at a higher freq
  uint1 fast_clock = 0;
  uint1 slow_clock = 0;
  uint1 locked = 0;
  ulx3s_clk_50_25 pll(
    clkin   <: clock,
    clkout0 :> fast_clock,
    clkout1 :> slow_clock,
    locked  :> locked
  );
$$end
$$if ICARUS then
  // in Icarus siumlation we match the ULX3S clocking scenario
  uint1 fast_clock = 0;
  simul_clk_166 pll(
    clkout0 :> fast_clock
  );
$$end

  uint16   kpressed   = 4;
$$if DE10NANO then
  keypad        kpad(kpadC :> kpadC, kpadR <: kpadR, pressed :> kpressed); 
$$end

  brom uint18 tiles[$16*16*L$] = {
$$for i=1,L do
$$write_image_in_table(PROBLEM .. 'tile_' .. string.format('%02d',i-1) .. '.tga',6)
$$end
  };

$$if ULX3S then
  dualport_bram uint$L$ domain<@clock,@fast_clock>[$GX*GY$] = {
$$else
  dualport_bram uint$L$ domain[$GX*GY$] = {
$$end
$$for i=1,GX*GY do
    $ones$,
$$end
  };

  uint16 seed    = 0;
  uint16 offset  = 0;
  uint1  wfc_run = 0;
  
$$if ULX3S or ICARUS then
  wfc wfc1<@fast_clock>(
$$else
  wfc wfc1(
$$end
    we       :> domain.wenable1,
    addr     :> domain.addr1,
    data_out :> domain.wdata1,
    offset   <: offset,
    seed     <: seed,
    wfc_run  <: wfc_run
  );

  uint1 in_domain := (pix_x >= $16$); // skips first tile TODO: fix this

  pix_r := 0; pix_g := 0; pix_b := 0;  
  
  wfc_run := 0; // pulses high to run wfc (allows crossing clock domain)
  
  wfc_run = 1; // run it once to initialize with a result
  
  // ---- display domain  
  while (1) { 
  
	  uint8   tile       = 0;
    uint16  domain_row = 0;
    domain.addr0       = 0; // restart domain scanning
    
	  while (pix_vblank == 0) {
      
      if (pix_active) {
        if (pix_x == 639) {
          if ((pix_y&15) == 15) {
            // next row
            domain_row   = domain_row + $GX$;
            domain.addr0 = domain_row; 
          } else {
            // reset to start of row
            domain.addr0 = domain_row; 
          }
        } else {
          if ((pix_x&15) == 13) { // move to next site
            if (domain.addr0 < domain_row + $GX-1$) {
              domain.addr0 = domain.addr0 + 1;
            } else {
              domain.addr0 = domain.addr0;
            }
          }
        }
        
        // set rgb data
        pix_b = in_domain ? tiles.rdata[ 0,6] : 0;
        pix_g = in_domain ? tiles.rdata[ 6,6] : 0;
        pix_r = in_domain ? tiles.rdata[12,6] : 0;
        //      ^^^^^^^^^^^ hides a defect on first tile of each row ... yeah, well ...
        {
          // read next pixel
          uint10 x = uninitialized;
          uint10 y = uninitialized;
          x = (pix_x == 639) ? 0       : pix_x+1;
          y = (pix_x == 639) ? pix_y+1 : pix_y;
          tiles .addr  = (x&15) + ((y&15)<<4) + (tile<<8);
          // select next tile
          if ((pix_x&15) == 14) {
            switch (domain.rdata0) {
              default: { tile = 0; }
$$for i=1,L do
              case $L$d$1<<(i-1)$: { tile = $i-1$; }
$$end
            }
          }
        }
      }
    }
    
$$if DE10NABO then        
    if ((kpressed & 4) != 0) {
$$elseif ULX3S then
    if (btn[4,1] != 0) {
$$else
    if (1) {
$$end    
        
        // wfc
        wfc_run = 1;
        
        seed = seed + 101;
    }
    
    // wait for sync
    while (pix_vblank == 1) {} 
  }

}

// -------------------------
