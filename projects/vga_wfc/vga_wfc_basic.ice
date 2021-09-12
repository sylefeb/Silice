// SL 2020-07-13
// Wave function collapse / Model synthesis (with image output)
// MIT license, see LICENSE_MIT in Silice repo root

$$if DE10NANO or SIMULATION then
$$Nlog = 3
$$else
$$Nlog = 3
$$end

$$N = (1<<Nlog)

$$if not SIMULATION then
$$BUTTONS = 1
$$end

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

$$function neighbors(i)
$$  local x   = i%N
$$  local y   = i//N
$$  local xm1 = x-1
$$  local xp1 = x+1
$$  local ym1 = y-1
$$  local yp1 = y+1
$$  -- make toroidal if outside of grid
$$  if xm1 < 0   then xm1 = N-1 end
$$  if xp1 > N-1 then xp1 = 0   end
$$  if ym1 < 0   then ym1 = N-1 end
$$  if yp1 > N-1 then yp1 = 0   end
$$  local l = xm1+y*N
$$  local r = xp1+y*N
$$  local t = x+ym1*N
$$  local b = x+yp1*N
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
  output uint16  addr,
  output uint$L$ data,
  input  uint16  seed
)
{
  // all sites, initialized so that everything is possible
$$for i=1,N*N do
  uint$L$ grid_$i-1$ = $ones$;
$$end
$$for i=1,N*N do
  uint$L$ new_grid_$i-1$ = uninitialized;
  uint1   nstable_$i-1$  = uninitialized;
$$end    
  
  // all rule-processors
$$for i=1,N*N do
$$ l,r,t,b = neighbors(i-1)
  wfc_rule_processor proc_$i-1$(
    site    <:: grid_$i-1$,
    left    <:: grid_$l$,
    right   <:: grid_$r$,
    top     <:: grid_$t$,
    bottom  <:: grid_$b$,
    newsite :>  new_grid_$i-1$,
    nstable :>  nstable_$i-1$
  );
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
$$for i=0,N*N-2 do
          nstable_$i$,
$$end        
          nstable_$N*N-1$
          };
		  
  // next entry to be collapsed
  uint16 next = 0;
  // random
  uint16 rand = 0;
    
  // grid updates
$$for i=1,N*N do
  grid_$i-1$ := new_grid_$i-1$;
$$end

  rand = seed + 7919;

  __display("wfc start");

  // while not fully resolved ...
  while (next < $N*N$) {
    
    // choose
    {
      switch (next) {
        default: { site = 0; }
$$for i=1,N*N do
        case $i-1$: { site = grid_$i-1$; }
$$end      
      }
++: // wait for choice to be made, then store
      switch (next) {
        default: {  }
$$for i=1,N*N do
        case $i-1$: { grid_$i-1$ = choice; }
$$end      
      }
    }
    
    // wait propagate
    while (nstable_reduce) { }
            
    // display the grid
    __display("-----");
$$for j=1,N do
    __display("%x %x %x %x %x %x %x %x",
$$for i=1,N-1 do
        grid_$(i-1)+(j-1)*N$,
$$end
        grid_$(N-1)+(j-1)*N$
    );
$$end
    
    rand = rand * 31421 + 6927;
    next = next + 1;
  }
  
  // write to output
  next = 0;
  while (next < $N*N$) {
    addr = next;
    switch (next) {
      default: {  }
$$for i=1,N*N do
        case $i-1$: { data = grid_$i-1$; }
$$end      
    }    
    next = next + 1;
  }
  
  __display("wfc done");  
  
}

// -------------------------

algorithm frame_display(
  input   uint10 pix_x,
  input   uint10 pix_y,
  input   uint1  pix_active,
  input   uint1  pix_vblank,
$$if not SIMULATION then
  input   uint$NUM_BTNS$ btns,
$$end  
  output! uint$color_depth$ pix_r,
  output! uint$color_depth$ pix_g,
  output! uint$color_depth$ pix_b
) <autorun> {

  brom uint18 tiles[$16*16*L$] = {
$$for i=1,L do
$$write_image_in_table(PROBLEM .. 'tile_' .. string.format('%02d',i-1) .. '.tga',6)
$$end
  };

  simple_dualport_bram uint$L$ result[$N*N$] = uninitialized;

  uint16         iter     = 0;
$$if not SIMULATION then
  uint$NUM_BTNS$ reg_btns = 0;
$$end  

  wfc wfc1(
    addr :> result.addr1,
    data :> result.wdata1,
    seed <: iter
  );

  pix_r := 0; pix_g := 0; pix_b := 0;  
  
$$if not SIMULATION then
  reg_btns ::= btns;
$$end

  result.wenable1 = 1;

  result.addr0 = 0;

  // ---- display result  
  while (1) {   
	  uint8   tile = 0;
	  while (pix_vblank == 0) {
      if (pix_active) {      
        // set rgb data
        pix_b = pix_x > 15 ? tiles.rdata[ 0,6] : 0;
        pix_g = pix_x > 15 ? tiles.rdata[ 6,6] : 0;
        pix_r = pix_x > 15 ? tiles.rdata[12,6] : 0;
        //      ^^^^^^^^^^^ hides a defect on first tile of each row ... yeah, well ...
        {
          // read next pixel
          uint10 x = uninitialized;
          uint10 y = uninitialized;
          x = (pix_x == 639) ? 0       : pix_x+1;
          y = (pix_x == 639) ? pix_y+1 : pix_y;
          tiles .addr  = (x&15) + ((y&15)<<4) + (tile<<8);
          // read next tile
          if ((pix_x&15) == 13) {
            // read grid ahead of vga beam
            result.addr0 = (((pix_x>>4)+1)&$N-1$) + (((pix_y>>4)&$N-1$)<<$Nlog$);
          } else { if ((pix_x&15) == 14) {
            // select next tile
            switch (result.rdata0) {
              default: {  }
$$for i=1,L do
              case $L$d$1<<(i-1)$: { tile = $i-1$; }
$$end
            }
          } }
        }
      }
    }
$$if not SIMULATION then
    if (reg_btns[1,1] != 0) {
$$else
    if (1) {
$$end    
      while (1) {
        
        () <- wfc1 <- ();

        iter = iter + 1;
        
        if (result.rdata0 != 0) {
          break;
        }
      }
    }
    
    // wait for sync
    while (pix_vblank == 1) {} 
  }

}

// -------------------------
