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
$include('../common/video_sdram_main.ice')

// fixed point precisions
$$FPl = 48 
$$FPw = 24
$$FPm = 12

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

  $spritechip$

  // Writes a raw pixel in the framebuffer
  subroutine writeRawPixel(
     reads  sbusy,
     writes sdata_in,
     writes saddr,
     writes swbyte_addr,
     writes sin_valid,
     reads  fbuffer,
     input  uint9  pi,
     input  uint9  pj,
     input  uint8  pidx
     )
  {
    while (1) {
      if (sbusy == 0) { // not busy?
        sdata_in    = pidx;
        saddr       = {~fbuffer,21b0} | (pi >> 2) | (pj << 8);
        swbyte_addr = pi & 3;
        sin_valid   = 1; // go ahead!
        break;
      }
    }
    return;  
  }

  uint1    vsync_filtered = 0;

  uint12   angle   = 0;
  uint8    frame   = 0;

  uint8    sprt    = 0;
  uint16   sprt_w  = 0;
  uint16   sprt_h  = 0;
  int16    sprt_lo = 0;
  int16    sprt_to = 0;
  int10    i       = 0;
  int10    j       = 0;
  int10    c       = 0;
  int10    r       = 0;
  int1     m       = 0;

  int$FPw$ y_accum   = 0;
  int10    y_last    = 0;
  int10    y_cur     = 0;
  int$FPw$ scale     = $1 << 8$; 
  
  vsync_filtered ::= vsync;

  sin_valid := 0; // maintain low (pulses high when needed)
  
  srw = 1;        // sdram write

  fbuffer = 0;
  
  while (1) {
    
    // clear screen
    i = 0;
    while (i < 320) {
      j = 0;
      while (j < 200) {
        () <- writeRawPixel <- (i,j,0);
        j = j + 1;
      }
      i = i + 1;
    }
    
    // select sprite
    (sprt,m) = spriteWalk(angle,frame);
    
    // read sprite info
    sprites_header   .addr = sprt;
    sprites_colstarts.addr = sprt;
++:
    sprt_w  = sprites_header.rdata[48,16];
    sprt_h  = sprites_header.rdata[32,16];
    sprt_lo = 100 - sprites_header.rdata[16,16];
    sprt_to = 100 - sprites_header.rdata[ 0,16];
    c = 0;
    while (c < sprt_w) { // for each column
      // retrieve column pointer
      if (m) {
        sprites_colptrs.addr = sprites_colstarts.rdata + sprt_w - 1 - c;
      } else {
        sprites_colptrs.addr = sprites_colstarts.rdata + c;
      }
++:
      sprites_data.addr = sprites_colptrs.rdata;      
++:
      // init first post
      j                 = sprites_data.rdata;      
      if (j != 255) {
        sprites_data.addr = sprites_data.addr + 1;
++:
        // num in post
        i                 = sprites_data.rdata;
        sprites_data.addr = sprites_data.addr + 2; // skip one      
        // draw the column
        r       = 0;        
        y_accum = 0;
        y_last  = 0;
        // go ahead
        while (sprites_data.rdata != 255 && r < sprt_h) { // we advance 1-by-1 for scaling
          if (i == 0) {
            // start new post
            j                 = sprites_data.rdata;
            sprites_data.addr = sprites_data.addr + 1;
++:
            // num in post
            i = sprites_data.rdata;
            sprites_data.addr = sprites_data.addr + 2; // skip one
          }
          if (r >= j && i != 0) {
            // draw post
            y_cur = (y_accum >> 8);
            while (y_last <= y_cur) {
              () <- writeRawPixel <- (c + sprt_lo,y_last + sprt_to,sprites_data.rdata);
              y_last = y_last + 1;
            }
            j = j + 1;
            i = i - 1;
            if (i == 0) {
              // skip last
              sprites_data.addr = sprites_data.addr + 2;
            } else {
              sprites_data.addr = sprites_data.addr + 1;
            }
          } else {
            y_last = ((y_accum + scale) >> 8);
          }
          r       = r + 1;
          y_accum = y_accum + scale;
        }
      }
      // next column
      c = c + 1;      
    }

    
    // prepare next
    frame = frame + 1;
    if (frame >= 4) {
      frame = 0;
      angle = angle + 256;
    }
    
    // wait for frame to end
    while (vsync_filtered == 0) {}
    
    // swap buffers
    fbuffer = ~fbuffer;
  }
}
