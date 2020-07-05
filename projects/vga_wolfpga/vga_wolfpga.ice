// SL 2020-04-24
// Wolf3D!
//
// References:
// "Wolfenstein 3D black book" by Fabien Sanglard
// https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_DR_A.ASM

$$texfile = 'wolf.tga'
// get pallette in pre-processor
$$texfile_palette = get_palette_as_table(texfile,color_depth)
// the palette has 64 entries, create a second darker one
// in the next 64 entries
$$for i=1,64 do
$$  r = texfile_palette[i] % 64
$$  g = math.floor(texfile_palette[i]/64) % 64
$$  b = math.floor(texfile_palette[i]/(64*64)) % 64
$$  r = math.floor(r / 2)
$$  g = math.floor(g / 2)
$$  b = math.floor(b / 2)
$$  texfile_palette[64 + i] = r + g*64 + b*64*64;
$$end

$include('../common/video_sdram_main.ice')

$$FPw = 30
$$FPf = 12
$$FPm = 12

$$div_width    = 20
$$div_unsigned = 1
$include('../common/divint_any.ice')

$$Deg90  =  900
$$Deg180 = 1800
$$Deg270 = 2700
$$Deg360 = 3600
  
// -------------------------
/*
algorithm walker(
  output int$FPw$ posx,
  output int$FPw$ posy,
  output int16    angle
) <autorun> {

$$ LMost = lshift(2,FPf)
$$ RMost = lshift(14,FPf)
$$ TMost = lshift(2,FPf)
$$ BMost = lshift(14,FPf)
$$if SIMULATION then
$$ Step      = lshift(1,FPf)
$$ AngleStep = 300
$$else
$$ Step      = math.floor(lshift(1,FPf-5)*2/3)
$$ AngleStep = 10
$$end

  angle = -160;
  posx  = $LMost$;
  posy  = $TMost$;
    
  while (1) {
    while (posy < $BMost$) {
      posy = posy + $Step$;
    }  
    while (posy > $TMost$) {
      posy = posy - $Step$;
    }
  }

}
*/

// -------------------------

bitfield DrawColumn
{
  uint9  height,
  uint1  v_or_h,
  uint2  material,
  uint6  texcoord
}

// -------------------------

algorithm columns_drawer(
  // sdram
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
  // reading from column bram
  output uint9  addr,
  input  uint18 rdata, // NOTE, TODO: allow to use bitfield name (DrawColumn)
  output uint1  wen,
  // how many columns have been written
  input  uint9  num_in_cols,
  // how many collumns have been drawn
  output uint9  num_drawn_cols,
  // vsynch  
  input  uint1  vsync,  // vsynch
  // framebuffer selection
  input  uint1  fbuffer
) <autorun> { 

  uint9 y      = 0;
  uint9 yw     = 0;
  uint9 h      = 0;
  uint8 palidx = 0;
  
  uint20 v_tex       = 0;
  uint20 v_tex_incr  = 0;

  // texture data
  brom uint8 texture[] = {
$$write_image_in_table(texfile)
  };

  // table for vertical interpolation
  brom int20 hscr_inv[512]={
    1, // 0: unused
$$for hscr=1,511 do
    $math.floor(0.5 + 262144/hscr)$,
$$end
  };

  wen         := 0; // reading from bram
  sd.in_valid := 0; // maintain low (pulses high when needed)  
  sd.rw       := 1; // writing to sdram

  while (1) {
  
    addr           = 0;
    num_drawn_cols = 0;
    while (num_drawn_cols < num_in_cols) {

      if (DrawColumn(rdata).height < 100) {
        h = DrawColumn(rdata).height;
      } else {
        h = 99;        
      }

      hscr_inv.addr = DrawColumn(rdata).height & 511;
      v_tex = $lshift(32,13)$;
  ++:      
      v_tex_incr    = hscr_inv.rdata;

      y = 0;
      while (y < 100) {
        // floor and bottom half
        if (y <= h) {

          texture.addr = ((DrawColumn(rdata).texcoord
                       + ((DrawColumn(rdata).material)<<6)) & 255) + (((v_tex >> 13) & 63)<<8);
  ++:          
          if (DrawColumn(rdata).v_or_h == 1) {
            palidx       = texture.rdata;
          } else {
            palidx       = texture.rdata + 64;
          }

          //palidx = 63;          
        } else {
          palidx = 22;  
        }
        // write to sdram
        yw = 100+y;
        while (1) {
          if (sd.busy == 0) { // not busy?
            sd.data_in    = palidx;
            sd.addr       = {1b0,~fbuffer,21b0} | (num_drawn_cols >> 2) | (yw << 8); 
            sd.wbyte_addr = num_drawn_cols & 3;
            sd.in_valid   = 1; // go ahead!
            break;
          }
        }          
        // other half
        if (y <= h) {
        
          texture.addr = ((DrawColumn(rdata).texcoord
                       + (DrawColumn(rdata).material<<6)) & 255) + ((63 - ((v_tex >> 13) & 63))<<8);
  ++:          
          if (DrawColumn(rdata).v_or_h == 1) {
            palidx       = texture.rdata;
          } else {
            palidx       = texture.rdata + 64;
          }
        
          //palidx = 55;
        } else {
          palidx = 2;
        }
        
        // write to sdram
        yw = 100-y;
        while (1) {
          if (sd.busy == 0) { // not busy?
            sd.data_in    = palidx;
            sd.addr       = {1b0,~fbuffer,21b0} | (num_drawn_cols >> 2) | (yw << 8); 
            sd.wbyte_addr = num_drawn_cols & 3;
            sd.in_valid   = 1; // go ahead!
            break;
          }
        }
        if (y <= h) {
          v_tex = v_tex + v_tex_incr;
        }
        y = y + 1;        
      }      
      
      // next
      num_drawn_cols = num_drawn_cols + 1;
      addr           = num_drawn_cols;
    }    
   
    // wait for frame to end
    while (vsync == 0) {}
    
  }
}

// -------------------------

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
$$if HAS_COMPUTE_CLOCK then
  input  uint1  sdram_clock,
  input  uint1  sdram_reset,
$$end
  input  uint1  vsync,
  output uint1  fbuffer,
  output uint8  led
) <autorun> {

  uint1  vsync_filtered = 0;

  // NOTE, TODO: cannot yet declare the bram with the bitfield
  // bram DrawColumn columns[320] = {};
$$if HAS_COMPUTE_CLOCK then   
  dualport_bram uint18 columns<@clock,@sdram_clock>[320] = {};
$$else
  dualport_bram uint18 columns[320] = {};
$$end

  // ray-cast columns counter  
  uint9 c       = 0;
  // drawn columns counter
  uint9 c_drawn = 0;

  columns_drawer coldrawer
$$if HAS_COMPUTE_CLOCK then
  <@sdram_clock,!sdram_reset>
$$end
  (
    sd      <:> sd,
    vsync   <: vsync_filtered,
    fbuffer <: fbuffer,
    addr    :> columns.addr1,  // drives port1 of columns
    wen     :> columns.wenable1,
    rdata   <: columns.rdata1,
    num_in_cols    <: c,
    num_drawn_cols :> c_drawn
  );

$$ tan_tbl = {}
$$ for i=0,449 do
$$   tan_tbl[i] = math.tan(2*math.pi*i/3600)
$$ end
  
  // tangent table
  // this is carefully created so that
  // - both tan/cot match (v and 1/v) to avoid gaps at corners
  // - the asymptotic end do not reach excessively large values
  brom int$FPw$ tan_f[900] = { // 900 is 3600/4, a quarter of all angles
$$for i=0,449 do
     $math.floor(0.5 + lshift(1,FPf) * tan_tbl[i])$,
$$end
$$for i=0,447 do
     $math.floor(0.0 + lshift(1,FPf) / tan_tbl[449-i])$,
$$end
  $math.floor(0.0 + lshift(1,FPf) / tan_tbl[2])$,
  $math.floor(0.0 + lshift(1,FPf) / tan_tbl[2])$,
  };
  
  brom int$FPw$ sin_m[2048] = {
$$for i=0,2047 do
    $math.floor(lshift(1,FPm) * math.sin(2*math.pi*i/2048))$,
$$end
  };

  // level definition
  brom uint3 level[$16*16$] = {
   1,1,1,1,1,1,4,1,4,1,1,2,1,1,1,1,
   1,0,0,0,0,0,0,0,0,0,0,2,0,0,0,4,
   1,0,0,0,0,0,0,0,0,0,0,3,0,0,0,4,
   1,0,0,0,0,0,0,0,0,0,0,2,0,0,0,4,
   1,0,0,0,0,0,0,0,0,0,0,2,2,2,2,2,
   1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,
   1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,
   1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,
   1,0,0,0,0,0,0,0,0,0,1,1,1,0,0,4,
   1,0,0,0,1,0,1,0,1,0,0,0,1,0,0,4,
   1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,
   1,0,0,0,0,0,1,0,0,2,0,0,1,0,0,4,
   1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,
   1,0,0,0,1,0,1,0,1,0,1,0,1,0,0,4,
   1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,
   1,1,1,1,1,1,4,1,4,1,4,1,1,1,1,1,
  };
    
  int$FPw$ posx_f  = $lshift(2,FPf)$;
  int$FPw$ posy_f  = $lshift(2,FPf)$;
  int16    posa    = 0;
  int$FPw$ hitx_f  = 0;
  int$FPw$ hity_f  = 0;
  int$FPw$ xstep_f = 0;
  int$FPw$ ystep_f = 0;
 
  int$FPw$ fracx_up_m = 0;
  int$FPw$ fracx_dw_m = 0;
  int$FPw$ fracy_up_m = 0;
  int$FPw$ fracy_dw_m = 0;
  int$FPw$ fracx_m    = 0;
  int$FPw$ fracy_m    = 0;

  int$FPw$ cosview_m  = 0;
  int$FPw$ sinview_m  = 0;

  int$FPw$ mapx     = 0;
  int$FPw$ mapy     = 0;
  int$FPw$ mapxstep = 0;
  int$FPw$ mapystep = 0;
  int$FPw$ mapxtest = 0;
  int$FPw$ mapytest = 0;
  
  int$FPw$ tmp1   = 0;
  int$FPw$ tmp2   = 0;
  int$FPw$ dist_f = 0;
  int$FPw$ height = 0;
  
  uint1  dir_y = 0;
  
  div$div_width$ div;
  
  uint3     hit         = 0;
  uint1     v_or_h      = 0;
  
  int16     viewangle   = 0;
  int16     colangle    = 0;
  
  /*
$$if not ICARUS then
  walker walk<@vsync_filtered>(
    posx  :> posx_f,
    posy  :> posy_f,
    angle :> posa
  );
$$end
*/
  vsync_filtered ::= vsync;

  fbuffer = 0;
  
  columns.wenable0 = 1; // write on port 0
  
  while (1) {
    
    viewangle = ((160 + posa) * $math.floor(2048*(2048/3600))$) >> 11;
    
    // get cos/sin view
    sin_m.addr = (viewangle) & 2047;
++:    
    sinview_m  = sin_m.rdata;
    sin_m.addr = (viewangle + 512) & 2047;
++:    
    cosview_m  = sin_m.rdata;

    // raycast columns
    c = 0;
    while (c < 320) {

      // start cell 
      mapx       = (posx_f >> $FPf$);
      mapy       = (posy_f >> $FPf$);
++:      
      // fracx_dw_m = (posx_f >> $FPf-FPm$) & $lshift(1,FPm)-1$;
      fracx_dw_m = (posx_f) & $lshift(1,FPm)-1$;
      fracx_up_m = $lshift(1,FPm)-1$ - fracx_dw_m;      
++:      
      // fracy_dw_m = (posy_f >> $FPf-FPm$) & $lshift(1,FPm)-1$;
      fracy_dw_m = (posy_f) & $lshift(1,FPm)-1$;
      fracy_up_m = $lshift(1,FPm)-1$ - fracy_dw_m;      
++:      
      
      colangle   = posa + c;
      while (colangle < 0) {
        colangle = colangle + 3600;
      }
      while (colangle > 3600) {
        colangle = colangle - 3600;
      }
      
      if (colangle < $Deg90$) {
        mapxstep   =  1;
        mapystep   = -1;
        fracx_m    = fracx_up_m;
        fracy_m    = fracy_dw_m;
        tan_f.addr = $Deg90-1$-colangle;
++:
        xstep_f    = tan_f.rdata;        
        tan_f.addr = colangle;
++:
        ystep_f    = - tan_f.rdata;        
      } else {
        if (colangle < $Deg180$) {
          mapxstep   = -1;
          mapystep   = -1;
          fracx_m    = fracx_dw_m;
          fracy_m    = fracy_dw_m;
          tan_f.addr = colangle - $Deg90$;
++:
          xstep_f    = - tan_f.rdata;        
          tan_f.addr = $Deg180-1$-colangle;
++:
          ystep_f    = - tan_f.rdata;        
        } else {
          if (colangle < $Deg270$) {
            mapxstep   = -1;
            mapystep   =  1;
            fracx_m    = fracx_dw_m;
            fracy_m    = fracy_up_m;
            tan_f.addr = $Deg270-1$-colangle;
++:
            xstep_f    = - tan_f.rdata;        
            tan_f.addr = colangle - $Deg180$;
++:
            ystep_f    = tan_f.rdata;        
          } else {
            mapxstep   =  1;
            mapystep   =  1;
            fracx_m    = fracx_up_m;
            fracy_m    = fracy_up_m;
            tan_f.addr = colangle-$Deg270$;
++:
            xstep_f    = tan_f.rdata;        
            tan_f.addr = $Deg360-1$-colangle;
++:
            ystep_f    = tan_f.rdata;            
          }        
        }   
      }
++:           
      // first intersection
      hity_f = posy_f + ((fracx_m * ystep_f) >>> $FPm$);
      mapx   = mapx + mapxstep;
// ++:   // (relax timing)      
      hitx_f = posx_f + ((fracy_m * xstep_f) >>> $FPm$);
      mapy   = mapy + mapystep;
++:
      // DDA wolfenstein-style main loop
      hit    = 0;
      v_or_h = 0; // 0: vertical (along x) 1: horizontal (along y)
      while (hit == 0) {
      
        mapxtest = hitx_f >>> $FPf$;
        mapytest = hity_f >>> $FPf$;
++:             
        // shall we do vertical or horizontal?
        if (v_or_h == 0) {
          // keep doing vertical?
          if (mapystep > 0 && mapytest >= mapy) {
            v_or_h = 1;
          } else {
          if (mapystep < 0 && mapytest <= mapy) {
            v_or_h = 1;
          } }
        } else {
          // keep doing horizontal?
          if (mapxstep > 0 && mapxtest >= mapx) {
            v_or_h = 0;
          } else {
          if (mapxstep < 0 && mapxtest <= mapx) {
            v_or_h = 0;
          } } 
        }
++:      
        // advance 
        if (v_or_h == 0) {
          // check for a hit on vertical edges
          level.addr = (mapx&15) + (((mapytest)&15)<<4);
          // hit = level[(mapx&15) + (((mapytest)&15)<<4)];
++:      
          hit = level.rdata;
          if (hit != 0) {
            if (mapxstep < 0) {
              hitx_f = (mapx+1) << $FPf$;
            } else {
              hitx_f = mapx << $FPf$;
            }
          } else {
            mapx   = mapx   + mapxstep;
            hity_f = hity_f + ystep_f;
          }
        } else {
          // check for a hit on horizontal edges
          level.addr = ((mapxtest)&15) + ((mapy&15)<<4);
          // hit = level[((mapxtest)&15) + ((mapy&15)<<4)];
++:      
          hit = level.rdata;
          if (hit != 0) {
            if (mapystep < 0) {
              hity_f = (mapy+1) << $FPf$;
            } else {
              hity_f = mapy << $FPf$;
            }
          } else {
            mapy   = mapy   + mapystep;
            hitx_f = hitx_f + xstep_f;
          }
        }
      }
      
++:      
      // compute distance
      tmp1   = (cosview_m * (hitx_f - posx_f)) >>> $FPm$;
// ++:   // relax timing      
      tmp2   = (sinview_m * (hity_f - posy_f)) >>> $FPm$;
++:   // relax timing      
      dist_f = (tmp1 - tmp2);
++:   // relax timing      

      // projection divide      
      (height) <- div <- ($140<<FPf$,dist_f>>1);

      columns.addr0 = c;
      DrawColumn(columns.wdata0).height   = height;
      DrawColumn(columns.wdata0).v_or_h   = v_or_h;
      DrawColumn(columns.wdata0).material = hit-1;
      DrawColumn(columns.wdata0).texcoord = (v_or_h == 0) ? (hity_f >>> $FPf-6$) : (hitx_f >>> $FPf-6$);
      
      // write on loop     
      c = c + 1;
    }
       

    // wait for drawer to end
    while (c_drawn < 320) {}

    // wait for frame to end
    while (vsync_filtered == 0) {}

$$ TMost = lshift(2,FPf)
$$ BMost = lshift(15,FPf)
    if (dir_y == 0) {
      if (posy_f < $BMost$) {
        posy_f = posy_f + 70;
      } else { 
        dir_y = 1;
      }
    } else {
      if (posy_f > $TMost$) {
        posy_f = posy_f - 70;
      } else {
        dir_y = 0;
      }
    }
    
    // swap buffers
    fbuffer = ~fbuffer;

  }

}

// ------------------------- 
