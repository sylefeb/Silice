// SL 2020-05-12
// DoomChip! Testing sprites
//
// References:
// - "DooM black book" by Fabien Sanglard
// - "DooM unofficial specs" http://www.gamers.org/dhs/helpdocs/dmsp1666.html

$$print('---< written in Silice by @sylefeb >---')

$$dofile('pre_load_data.lua')

$$dofile('pre_do_textures.lua')

$$dofile('pre_do_sprites.lua')

$$texfile_palette = palette_666
$$COL_MAJOR = 1
$include('../common/video_sdram_main.ice')

// fixed point precisions
$$FPl = 48 
$$FPw = 24
$$FPm = 12

$$div_width = FPw
$include('../common/divint_any.ice')

// -------------------------
// Main drawing algorithm

circuitry spriteWalk(input angle,input frame,output sprite,output mirror)
{
  // angle expect in 0 - 4095
  if (angle < 256) {
    sprite = frame * 5 + 2;
    mirror = 1;
  } else { if (angle < 768) {
    sprite = frame * 5 + 3;
    mirror = 1;
  } else { if (angle < 1280) {
    sprite = frame * 5 + 4;
    mirror = 0;
  } else { if (angle < 1792) {
    sprite = frame * 5 + 3;
    mirror = 0;
  } else { if (angle < 2304) {
    sprite = frame * 5 + 2;
    mirror = 0;
  } else { if (angle < 2816) {
    sprite = frame * 5 + 1;
    mirror = 0;
  } else { if (angle < 3328) {
    sprite = frame * 5 + 0;
    mirror = 0;
  } else { if (angle < 3840) {
    sprite = frame * 5 + 1;
    mirror = 1;
  } else {
    sprite = frame * 5 + 2;
    mirror = 1;
  } } } } } } } }
}

// ---------------------------------------------------

circuitry writePixel(
  inout  sd,  
  input  fbuffer,
  input  pi,
  input  pj,
  input  pixpal)
{
  while (1) {
    if (sd.busy == 0) { // not busy?
      sd.data_in    = pixpal;
$$if not COL_MAJOR then        
      sd.addr       = {~fbuffer,21b0} | (pi >> 2) | (pj << 8);
$$else
      sd.addr       = {~fbuffer,21b0} | ((pi >> 2) << 8) | (pj);
$$end
      sd.wbyte_addr = pi & 3;
      sd.in_valid   = 1; // go ahead!
      break;
    }
  }
}

// ---------------------------------------------------

algorithm frame_drawer(
  sdio sd {
    output addr,
    output wbyte_addr,
    output rw,
    output data_in,
    output in_valid,
    input  data_out,
    input  busy,
    input  out_valid,
  },
  input  uint1  vsync,
  output uint1  fbuffer
) {

  $spritechip$

  // clears the screen
  subroutine clearScreen(
    readwrites sd,
    reads      fbuffer
  ) {
    int10 i = 0;
    int10 j = 0;
    uint1 z = 0;
    // clear screen
    i = 0;
    while (i < 320) {
      j = 0;
      while (j < 200) {
        (sd) = writePixel(sd,fbuffer,i,j,z);
        j = j + 1;
      }
      i = i + 1;
    }
    return;
  }

  // draws a scaled sprite
  subroutine drawSprite(
    readwrites     sprites_header,
    readwrites     sprites_colstarts,
    readwrites     sprites_data,
    readwrites     sprites_colptrs,
    readwrites     sd,
    reads          fbuffer,    
    input uint8    sp,
    input uint1    mr,
    input int16    screenx,    
    input int16    screeny,
    input int$FPw$ dist
  ) {
    uint16   sprt_w  = 0;
    uint16   sprt_h  = 0;
    int16    sprt_lo = 0;
    int16    sprt_to = 0;

    int10    i       = 0;
    int10    c       = 0;
    int10    r       = 0;

    int10    v_post  = 0;
    int10    n_post  = 0;
    
    uint9    pi  = 0;
    uint9    pj  = 0;
    uint8    pal = 0;

    uint16   x_ext = 0;    
    uint16   y_ext = 0;    
    int10    x_last    = 0;

    uint10    u       = 0;
    int10     v       = 0;
    int10     cur_v   = 0;
    uint$FPw$ u_accum = 0;
    uint$FPw$ v_accum = 0;

    int10    y_first   = 0;
    int10    y_last    = 0;   

    uint8    pix = 17;

    int$FPw$ inv_dist = 0;
    
    (inv_dist) <- div <- ($(1<<(FPm*2 - 1))-1$,dist);
    
    // read sprite info
    sprites_header   .addr = sp;
    sprites_colstarts.addr = sp;
++:
    sprt_w  = sprites_header.rdata[48,16];
    sprt_h  = sprites_header.rdata[32,16];
    sprt_lo = screenx - sprites_header.rdata[16,16];
    sprt_to = screeny - sprites_header.rdata[ 0,16];
    
    // sprite w extent
    x_ext   = (sprt_w * inv_dist) >> $FPm-1$;
    y_ext   = (sprt_h * inv_dist) >> $FPm-1$;
    
    // screen bounds
    y_first = screeny - (y_ext);
    y_last  = screeny;
    c       = screenx - (x_ext>>1);
    x_last  = c + x_ext;
    
    u_accum = 0;
    while (c < x_last) {

      u       = u_accum >> $FPm$;

      // retrieve column pointer
      if (mr) {
        sprites_colptrs.addr = sprites_colstarts.rdata + sprt_w - 1 - u;
      } else {
        sprites_colptrs.addr = sprites_colstarts.rdata + u;
      }
++:
      sprites_data.addr = sprites_colptrs.rdata;
++:
      r       =  y_first;
      v_accum =  0;
      cur_v   = -1;
      n_post  =  0;   
      while (r <= y_last && sprites_data.rdata != 255) {
        
        v    = v_accum >> $FPm$;
        while (cur_v < v) { 
          if (n_post == 0) {
            // read next post
            v_post            = sprites_data.rdata; // != 255
            sprites_data.addr = sprites_data.addr + 1;
  ++:
            // num in post
            n_post            = sprites_data.rdata;
            sprites_data.addr = sprites_data.addr + 2; // skip one              
          }
          if (cur_v >= v_post) {
            n_post = n_post - 1;
            if (n_post == 0) {
              // skip last
              sprites_data.addr = sprites_data.addr + 2;
            } else {
              sprites_data.addr = sprites_data.addr + 1;
            }
          }
          cur_v = cur_v + 1;
        }
        
        if (v >= v_post && n_post != 0) {
          pix  = sprites_data.rdata;
          (sd) = writePixel(sd,fbuffer,c,r,pix);
        }
        
        v_accum = v_accum + dist;
        r = r + 1;
      }
      
      u_accum = u_accum + dist;
      c = c + 1;
    }
    
    return;
  }
  
  uint1    vsync_filtered = 0;

  uint12   angle   = 3042;
  uint8    frame   = 0;

  uint8    sprt    = 0;
  uint1    mirr    = 0;

  uint$FPw$ distv  = $20<<FPm$;

  div$FPw$ div;

  vsync_filtered ::= vsync;

  sd.in_valid := 0; // maintain low (pulses high when needed)
  
  sd.rw = 1;        // sdram write

  fbuffer = 0;
  
  while (1) {
    
    () <- clearScreen <- ();
    
    // select sprite
    (sprt,mirr) = spriteWalk(angle,frame);
    
    // draw sprite
    () <- drawSprite <- (sprt,mirr,100,140,distv);
    
    // prepare next
    frame = frame + 1;
    if (frame >= 4) {
      frame = 0;
      // angle = angle + 256;      
    }
    if (distv > $1<<FPm$) {
      distv = distv - 16;
    }
    
    // wait for frame to end
    while (vsync_filtered == 0) {}
    
    // swap buffers
    fbuffer = ~fbuffer;
  }
}

// ---------------------------------------------------
