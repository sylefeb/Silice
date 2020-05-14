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

  // writes a raw pixel in the framebuffer
  subroutine writeRawPixel(
     readwrites    sd,
     reads         fbuffer,
     input  uint9  pi,
     input  uint9  pj,
     input  uint8  pidx
     )
  {
    while (1) {
      if (sd.busy == 0) { // not busy?
        sd.data_in    = pidx;
        sd.addr       = {~fbuffer,21b0} | (pi >> 2) | (pj << 8);
        sd.wbyte_addr = pi & 3;
        sd.in_valid   = 1; // go ahead!
        break;
      }
    }
    return;  
  }

  // clears the screen
  subroutine clearScreen(calls writeRawPixel)
  {
    int10 i = 0;
    int10 j = 0;
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
    return;
  } 

  // draws a scaled sprite
  subroutine drawSprite(
    readwrites sprites_header,
    readwrites sprites_colstarts,
    readwrites sprites_data,
    readwrites sprites_colptrs,
    calls writeRawPixel,
    input int16    screenx,
    input int16    screeny,
    input int$FPw$ scale,
    input uint8    sp,
    input uint1    mr
  ) {
    uint16   sprt_w  = 0;
    uint16   sprt_h  = 0;
    int16    sprt_lo = 0;
    int16    sprt_to = 0;
    int10    i       = 0;
    int10    j       = 0;
    int10    c       = 0;
    int10    r       = 0;

    int$FPw$ y_accum   = 0;
    int10    y_last    = 0;
    int10    y_cur     = 0;
    
    int$FPw$ x_accum   = 0;
    int10    x_last    = 0;
    int10    x_cur     = 0;

    // read sprite info
    sprites_header   .addr = sp;
    sprites_colstarts.addr = sp;
++:
    sprt_w  = sprites_header.rdata[48,16];
    sprt_h  = sprites_header.rdata[32,16];
    sprt_lo = 100 - sprites_header.rdata[16,16];
    sprt_to = 100 - sprites_header.rdata[ 0,16];
    c = 0;
    x_accum = 0;
    x_last  = 0;
    x_cur   = 0;
    while (c < sprt_w) { // for each column
    
      x_cur = (x_accum >> 8);      
      
      while (x_last <= x_cur) {
      
        // retrieve column pointer
        if (mr) {
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
                () <- writeRawPixel <- (x_last + sprt_lo,y_last + sprt_to,sprites_data.rdata);
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
        
        x_last = x_last + 1;
      }
      
      // next column
      c = c + 1;     
      x_accum = x_accum + scale;
    }
    return;
  }
  
  uint1    vsync_filtered = 0;

  uint12   angle   = 0;
  uint8    frame   = 0;

  uint8    sprt    = 0;
  uint1    mirr    = 0;

  vsync_filtered ::= vsync;

  sd.in_valid := 0; // maintain low (pulses high when needed)
  
  sd.rw = 1;        // sdram write

  fbuffer = 0;
  
  while (1) {
    
    () <- clearScreen <- ();
    
    // select sprite
    (sprt,mirr) = spriteWalk(angle,frame);
    
    // draw sprite
    () <- drawSprite <- (sprt,mirr,100,100,1<<7);
    
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

// ---------------------------------------------------
