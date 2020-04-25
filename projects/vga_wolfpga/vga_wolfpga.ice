// SL 2020-04-24
// Wolf3D!
// see https://lodev.org/cgtutor/raycasting.html for principle
// or "Wolfenstien 3D black book" by Fabien Sanglard

$$texfile = 'wall.tga'

$include('../common/video_sdram_main.ice')

$$FPw = 24
$$FPf = 12 -- fractions precision
$$FPm = 7  -- precision within cells

$$div_width = FPw
$include('../common/divint_any.ice')

$$ ones = '' .. FPw .. 'b'
$$for i=1,FPw-1 do
$$ ones = ones .. '1'
$$end

// -------------------------

algorithm frame_drawer(
  output uint23 saddr,
  output uint2  swbyte_addr,
  output uint1  srw,
  output uint32 sdata_in,
  output uint1  sin_valid,
  input  uint32 sdata_out,
  input  uint1  sbusy,
  input  uint1  sout_valid,
  input  uint1  vsync,
  output uint1  fbuffer
) {

  div$FPw$ div;

  uint1  vsync_filtered = 0;

  bram uint8 texture[] = {   // texture from https://github.com/freedoom/freedoom
$$image_table(texfile)
  };
  
  bram uint9 columns[320];
  bram uint2 material[320];

  // ---------- table for text swim
  bram int8 wave[128] = {
$$for i=0,127 do
    $math.floor(127.0 * math.sin(2*math.pi*i/127))$,
$$end
  };
  
  uint2 level[$8*8$] = {
   1,2,1,2,1,2,1,1,
   1,0,1,0,1,0,0,2,
   2,0,0,0,0,0,1,1,
   1,1,0,0,0,0,0,2,
   2,0,0,0,0,0,1,1,
   1,1,0,0,0,0,0,2,
   2,0,0,1,0,1,0,1,
   1,1,2,1,2,1,2,1,
  };
  
  uint9 c = 0;
  uint9 y = 0;
  uint9 h = 0;
  uint8 palidx = 0;
  
  int$FPw$ posx_m = $lshift(4,FPm) + lshift(1,FPm-1)$;
  int$FPw$ posy_m = $lshift(4,FPm) + lshift(1,FPm-1)$;

  int$FPw$ mapx_m = 0;
  int$FPw$ mapy_m = 0;
  
  int$FPw$ raydirx_m    = 0;
  int$FPw$ raydiry_m    = 0;
  
  int$FPw$ invraydirx_f = 0;
  int$FPw$ invraydiry_f = 0;

  int$FPw$ deltax_f     = 0;
  int$FPw$ deltay_f     = 0;
  
  int$FPw$ stepx_m      = 0;
  int$FPw$ stepy_m      = 0;

  int$FPw$ sidex_f      = 0;
  int$FPw$ sidey_f      = 0;

  int$FPw$ dist_f       = 0;
  int$FPw$ height       = 0;

  uint2 hit  = 0;
  uint1 side = 0;
  uint7 frame = 0;
  
  vsync_filtered ::= vsync;

  sin_valid := 0; // maintain low (pulses high when needed)

  srw = 1;  // write

  fbuffer = 0;
  wave.wenable = 0;    
  
  while (1) {

    // ray cast columns
    c = 0;
    columns .wenable = 1;
    material.wenable = 1;
    raydirx_m =  $lshift(1,FPm)$;
    raydiry_m = -160;
    wave.addr = frame;    
++:
    posy_m = $lshift(4,FPm) + lshift(1,FPm-1)$ + wave.rdata;
    while (c < 320) {    
      
      // raycast

      // start cell      
      mapx_m = (posx_m >> $FPm$) << $FPm$;
      mapy_m = (posy_m >> $FPm$) << $FPm$;  

      // ray direction
      if (raydirx_m > -3 && raydirx_m < 3) { // raydirx too small
        invraydirx_f = $ones$;
        deltax_f     = $ones$;
      } else {
        (invraydirx_f) <- div <- ($lshift(1,FPf+FPm)$,raydirx_m);
        if (invraydirx_f < 0) {
          deltax_f = - invraydirx_f;
        } else {
          deltax_f = invraydirx_f;
        }
      }
      
      if (raydiry_m > -3 && raydiry_m < 3) { // raydiry too small
        invraydiry_f = $ones$;
        deltay_f     = $ones$;
      } else {      
        (invraydiry_f) <- div <- ($lshift(1,FPf+FPm)$,raydiry_m);
        if (invraydiry_f < 0) {
          deltay_f = - invraydiry_f;
        } else {
          deltay_f = invraydiry_f;
        }
      }

++:
      // init DDA
      if (raydirx_m < 0) {
        stepx_m  = $-1*lshift(1,FPm)$;
        sidex_f  = ((posx_m - mapx_m) * deltax_f) >> $FPm$;
      } else {
        stepx_m  = $ 1*lshift(1,FPm)$;
        sidex_f  = ((mapx_m + $lshift(1,FPm)$ - posx_m) * deltax_f) >> $FPm$;
      }

++:
      if (raydiry_m < 0) {
        stepy_m  = $-1*lshift(1,FPm)$;
        sidey_f  = ((posy_m - mapy_m) * deltay_f) >> $FPm$;
      } else {
        stepy_m  = $ 1*lshift(1,FPm)$;
        sidey_f  = ((mapy_m + $lshift(1,FPm)$ - posy_m) * deltay_f) >> $FPm$;
      }
      
      // DDA
      hit = 0;
      while (hit == 0) {
        if (sidex_f < sidey_f) {
          sidex_f = sidex_f + deltax_f;
          mapx_m  = mapx_m  + stepx_m;
          side    = 0;
        } else {
          sidey_f = sidey_f + deltay_f;
          mapy_m  = mapy_m  + stepy_m;
          side    = 1;
        }
        hit = level[(mapx_m[$FPm$,3]) + ((mapy_m[$FPm$,3])<<3)];
      }
      
      // distance
      if (side == 0) {
        dist_f = (( mapx_m + (($lshift(1,FPm)$-stepx_m)>>1) - posx_m ) * invraydirx_f) >> $FPm$;
      } else {
        dist_f = (( mapy_m + (($lshift(1,FPm)$-stepy_m)>>1) - posy_m ) * invraydiry_f) >> $FPm$;
      }

      (height) <- div <- ($lshift(50,FPf)$,dist_f);
      
      columns.addr   = c;
      columns.wdata  = height;
      material.addr  = c;
      material.wdata = {hit[0,1],side};

      // write on loop
      
      c = c + 1;
      raydiry_m = raydiry_m + 1;
    }
    
    // now draw columns
    c = 0;
    columns.wenable  = 0;
    material.wenable = 0;
    while (c < 320) {
      columns.addr  = c;
      material.addr = c;
++:
      h = columns.rdata;
      y = 0;
      while (y < 200) {
        // color to write
        palidx = 0;
        if (y >= 100 - h && y <= h + 100) {
          switch (material.rdata) 
          {
            case 0: { palidx = 10; }
            case 1: { palidx = 21; }
            case 2: { palidx = 25; }
            case 3: { palidx = 30; }
          }
        }
        // write to sdram
        while (1) {
          if (sbusy == 0) { // not busy?
            sdata_in    = palidx;
            saddr       = {~fbuffer,21b0} | ((c + (y << 8) + (y << 6)) >> 2); // * 240 / 4
            swbyte_addr = c & 3;
            sin_valid   = 1; // go ahead!
            break;
          }
        }          
        y = y + 1;        
      }      
      c = c + 1;
    }    
    
    // prepare next frame
    frame = frame + 1;

    // wait for frame to end
    while (vsync_filtered == 0) {}

    // swap buffers
    fbuffer = ~fbuffer;

  }

}

// ------------------------- 
