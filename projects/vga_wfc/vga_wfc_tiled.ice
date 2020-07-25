// SL 2020-07-13
// Wave function collapse (with image output)

$$if DE10NANO or SIMULATION then
$$N = 8
$$else
$$N = 8
$$end

$$T = 3
$$G = 1+T*N+1

$include('../common/empty.ice')
$include('../vga_demo/vga_demo_main.ice')

$$PROBLEM = 'problems/knots/'
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
      ({$L${right[$i-1$,1]}} & $L$b$Rleft[i]$)
$$if i < L then
    |
$$end      
$$end
    ) & (
$$for i=1,L do
      ({$L${left[$i-1$,1]}} & $L$b$Rright[i]$)
$$if i < L then
    |
$$end      
$$end
    ) & (
$$for i=1,L do
      ({$L${bottom[$i-1$,1]}} & $L$b$Rtop[i]$)
$$if i < L then
    |
$$end      
$$end
    ) & (
$$for i=1,L do
      ({$L${top[$i-1$,1]}} & $L$b$Rbottom[i]$)
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
// helper function to locate neighbors

$$function neighbors(i,j)
$$  local im1 = i-1
$$  local ip1 = i+1
$$  local jm1 = j-1
$$  local jp1 = j+1
$$  local l = {i=im1,j=j}
$$  local r = {i=ip1,j=j}
$$  local t = {i=i,j=jm1}
$$  local b = {i=i,j=jp1}
$$  return l,r,t,b
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
// main WFC algorithm

algorithm wfc(
  output! uint1   we,
  output! uint16  addr,
  input   uint$L$ data_in,
  output! uint$L$ data_out,
  input   uint16  offset,
  input   uint16  seed
)
{
  // all sites N+2 for left/right, top/bottom padding
$$for j=0,(N+2)-1 do
$$for i=0,(N+2)-1 do
  uint$L$ grid_$i$_$j$ = uninitialized;
$$end    
$$end
  // variables bound to rule processor outputs 
$$for j=1,N do
$$for i=1,N do
  uint$L$ new_grid_$i$_$j$ = uninitialized;
  uint1   nstable_$i$_$j$  = uninitialized;
$$end
$$end   
  // all rule-processors
$$for j=1,N do
$$for i=1,N do
$$ l,r,t,b = neighbors(i,j)
  wfc_rule_processor proc_$i$_$j$(
    site    <:: grid_$i$_$j$,
    left    <:: grid_$l.i$_$l.j$,
    right   <:: grid_$r.i$_$r.j$,
    top     <:: grid_$t.i$_$t.j$,
    bottom  <:: grid_$b.i$_$b.j$,
    newsite :>  new_grid_$i$_$j$,
    nstable :>  nstable_$i$_$j$
  );
$$end  
$$end  

  // algorithm for choosing a label
  uint$L$ site   = uninitialized;
  uint$L$ choice = uninitialized;
  makeAChoice chooser(
    i    <:: site,
    rand <:: rand,
    o    :>  choice
  );

  uint$N*N$ nstable_reduce := {
$$for i=1,N do
$$for j=1,N do
            nstable_$i$_$j$ $((i==N and j==N) and '' or ',')$
$$end        
$$end
          };		  
  // next entry to be collapsed
  uint8  next_i = 0;
  uint16 next_j = 0;
  uint16 next   = 0;
  // local address in grid
  uint16 local = 0;
  // random
  uint16 rand = 0;    
  // grid updates
  uint1  update_en = 0;
$$for j=1,N do
$$for i=1,N do
  grid_$i$_$j$ := update_en ? new_grid_$i$_$j$ : grid_$i$_$j$;
$$end
$$end

  rand = seed + 7919;

  __display("wfc start");

  // read from input
  we     = 0;
  next_j = 0;
  local  = 0;
  addr   = offset;
  while (next_j < $(N+2)*G$) {
    next_i = 0;
    addr   = local  + offset;
    while (next_i <= $N+2$) {
      switch (local) {
        default: {  }
$$for j=0,N+1 do
$$for i=0,N+1 do    
        case $i + j*G$: { grid_$i$_$j$ = data_in; }
$$end      
$$end      
      }    
      next_i = next_i + 1;
      local  = next_i + next_j;
      addr   = local  + offset;
    }
    next_j = next_j + $G$;
    local  = next_j;
  }

  // enable updates from rule-processors
  update_en = 1;

  // display the grid
  __display("----- INIT GRID -----");
$$for j=0,N+1 do
  __display("(%x) %x %x %x %x %x %x %x %x (%x)",
$$for i=0,N do
      grid_$i$_$j$,
$$end
      grid_$N+1$_$j$
  );
$$end

  // while not fully resolved ...  
  next = 0;
  while (next < $N*N$) {
    
    // choose
    {
      switch (next) {
        default: { site = 0; }
$$nxt = 0
$$for j=1,N do
$$for i=1,N do
        case $nxt$: { site = grid_$i$_$j$; }
$$nxt = nxt + 1        
$$end
$$end
      }
      
++: // wait for choice to be made, then store

      switch (next) {
        default: {  }
$$nxt = 0
$$for j=1,N do
$$for i=1,N do
        case $nxt$: { grid_$i$_$j$ = choice; }
$$nxt = nxt + 1        
$$end
$$end
      }
    }
    
    // wait propagate
    while (nstable_reduce) { }

    // display the grid
    __display("-----");
$$for j=0,N+1 do
    __display("(%x) %x %x %x %x %x %x %x %x (%x)",
$$for i=0,N do
        grid_$i$_$j$,
$$end
        grid_$N+1$_$j$
    );
$$end

    rand = rand * 31421 + 6927;
    next = next + 1;
  }

  // write to output (excluding padding)
  next_j = 0;
  addr   = offset;
  while (next_j < $(N+2)*G$) {
    next_i = 0;
    while (next_i < $N+2$) {
      local = next_i + next_j;    
      addr  = local + offset;
      we    = 1;
      switch (local) {
        default: { we = 0; }
$$for j=1,N do
$$for i=1,N do    
        case $i + j*G$: { data_out = grid_$i$_$j$; }
$$end      
$$end      
      }    
      next_i = next_i + 1;
    }
    next_j = next_j + $G$;
  }
  we = 0;

  __display("wfc done");  
  
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

  uint16   kpressed   = 4;
$$if DE10NANO then
  keypad        kpad(kpadC :> kpadC, kpadR <: kpadR, pressed :> kpressed); 
$$end

  brom uint18 tiles[$16*16*L$] = {
$$for i=1,L do
$$write_image_in_table(PROBLEM .. 'tile_' .. string.format('%02d',i-1) .. '.tga',6)
$$end
  };

  dualport_bram uint$L$ domain[$G*G$] = {
$$for i=1,G*G do
    $ones$,
$$end
  };

  uint16 iter   = 1;
  uint16 offset = 0;

  wfc wfc1(
    we       :> domain.wenable1,
    addr     :> domain.addr1,
    data_out :> domain.wdata1,
    data_in  <: domain.rdata1,
    offset   <: offset,
    seed     <: iter
  );

  uint1 in_domain := (pix_x >= $16$  && pix_y >= $16$ 
                   && pix_x < $(G-1)*16$ && pix_y < $(G-1)*16$);

  pix_r := 0; pix_g := 0; pix_b := 0;  
  
  domain.wenable0 = 0;

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
            domain_row   = domain_row + $G$;
            domain.addr0 = domain_row; 
          } else {
            // reset to start of row
            domain.addr0 = domain_row; 
          }
        } else {
          if ((pix_x&15) == 13) { // move to next site
            if (domain.addr0 < domain_row + $G-1$) {
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
$$for i=1,L do
              case $1<<(i-1)$: { tile = $i-1$; }
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
      while (1) {
        
        uint8  next_tile_j = 0;
        uint16 offset_row = 0;        
        while (next_tile_j < $T$) {
          uint8 next_tile_i = 0;
          offset   = offset_row;
          while (next_tile_i < $T$) {    
            __display("*** tile %d,%d ***",next_tile_i,next_tile_j);
            () <- wfc1 <- ();
            iter = iter + 1;
            offset      = offset + $N$;
            next_tile_i = next_tile_i + 1;
          }
          offset_row  = offset_row + $(N)*G$;
          next_tile_j = next_tile_j + 1;
        }
        
        if (domain.rdata0 != 0) {
          break;
        }
        
      }
    }
    
    // wait for sync
    while (pix_vblank == 1) {} 
  }

}

// -------------------------
