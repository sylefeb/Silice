// SL 2020-04-24
// Wolf3D!
//
// References:
// "Wolfenstien 3D black book" by Fabien Sanglard
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

$$div_width = FPw
$include('../common/divint_any.ice')

$$Deg90  =  900
$$Deg180 = 1800
$$Deg270 = 2700
$$Deg360 = 3600
  
// -------------------------

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

  uint1  vsync_filtered = 0;

  bram uint8 texture[] = {
$$write_image_in_table(texfile)
  };
  
  bram uint10 columns[320];
  bram uint3  material[320];
  bram uint6  texcoord[320];
  
$$ tan_tbl = {}
$$ for i=0,449 do
$$   tan_tbl[i] = math.tan(2*math.pi*i/3600)
$$ end
  
  // tangent table
  // this is carefully created so that
  // - both tan/cot match (v and 1/v) to avoid gaps at corners
  // - the asymptotic end do not reach excessively large values
  bram int$FPw$ tan_f[900] = { // 900 is 3600/4, a quarter of all angles
$$for i=0,449 do
     $math.floor(0.5 + lshift(1,FPf) * tan_tbl[i])$,
$$end
$$for i=0,447 do
     $math.floor(0.0 + lshift(1,FPf) / tan_tbl[449-i])$,
$$end
  $math.floor(0.0 + lshift(1,FPf) / tan_tbl[2])$,
  $math.floor(0.0 + lshift(1,FPf) / tan_tbl[2])$,
  };
  
  bram int$FPw$ sin_m[2048] = {
$$for i=0,2047 do
    $math.floor(lshift(1,FPm) * math.sin(2*math.pi*i/2048))$,
$$end
  };

  // table for vertical interpolation
  bram int20 hscr_inv[512]={
    1, // 0: unused
$$for hscr=1,511 do
    $math.floor(0.5 + 262144/hscr)$,
$$end
  };

  uint3 level[$16*16$] = {
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
  
  uint9 c      = 0;
  uint9 y      = 0;
  uint9 yw     = 0;
  uint9 h      = 0;
  uint8 palidx = 0;
  
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
  
  div$FPw$ div;
  
  uint3     hit         = 0;
  uint1     v_or_h      = 0;

  int16     viewangle   = 0;
  int16     colangle    = 0;
  
  uint20    v_tex       = 0;
  uint20    v_tex_incr  = 0;
  
$$if not ICARUS then
  walker walk<@vsync>(
    posx  :> posx_f,
    posy  :> posy_f,
    angle :> posa
  );
$$end

  vsync_filtered ::= vsync;

  sin_valid := 0; // maintain low (pulses high when needed)
  
  srw = 1;        // sdram write

  fbuffer = 0;
  
  sin_m.wenable    = 0;    
  tan_f.wenable    = 0;
  hscr_inv.wenable = 0;
  texture.wenable  = 0;
  
  while (1) {

    columns .wenable = 1;
    material.wenable = 1;
    texcoord.wenable = 1;
    
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
      
      fracx_dw_m = (posx_f >> $FPf-FPm$) & $lshift(1,FPm)-1$;
      fracx_up_m = $lshift(1,FPm)-1$ - fracx_dw_m;      
      fracy_dw_m = (posy_f >> $FPf-FPm$) & $lshift(1,FPm)-1$;
      fracy_up_m = $lshift(1,FPm)-1$ - fracy_dw_m;      
      
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
      
      // first intersection
      hity_f = posy_f + ((fracx_m * ystep_f) >>> $FPm$);
      mapx   = mapx + mapxstep;
++:   // (relax timing)      
      hitx_f = posx_f + ((fracy_m * xstep_f) >>> $FPm$);
      mapy   = mapy + mapystep;
      
      // DDA wolfenstein-style main loop
      hit    = 0;
      v_or_h = 0; // 0: vertical (along x) 1: horizontal (along y)
      while (hit == 0) {
      
        mapxtest = hitx_f >>> $FPf$;
        mapytest = hity_f >>> $FPf$;
        
        // shall we do vertical or horizontal?
        if (v_or_h == 0) {
          // keep doing vertical?
          if (mapystep > 0 && mapytest >= mapy) {
            v_or_h = 1;
          }
          if (mapystep < 0 && mapytest <= mapy) {
            v_or_h = 1;
          }
        } else {
          // keep doing horizontal?
          if (mapxstep > 0 && mapxtest >= mapx) {
            v_or_h = 0;
          }
          if (mapxstep < 0 && mapxtest <= mapx) {
            v_or_h = 0;
          }        
        }

        // advance 
        if (v_or_h == 0) {
          // check for a hit on vertical edges
          hit = level[(mapx&15) + (((mapytest)&15)<<4)];
          if (hit != 0) {
            if (mapxstep < 0) {
              hitx_f = (mapx+1) << $FPf$;
            } else {
              hitx_f = mapx << $FPf$;
            }
            break;
          }
          mapx   = mapx   + mapxstep;
          hity_f = hity_f + ystep_f;
        } else {
          // check for a hit on horizontal edges
          hit = level[((mapxtest)&15) + ((mapy&15)<<4)];
          if (hit != 0) {
            if (mapystep < 0) {
              hity_f = (mapy+1) << $FPf$;
            } else {
              hity_f = mapy << $FPf$;
            }
            break;
          }
          mapy   = mapy   + mapystep;
          hitx_f = hitx_f + xstep_f;
        }
      }

      // compute distance, using custom multipliers to fit timing
      tmp1   = (cosview_m * (hitx_f - posx_f)) >>> $FPm$;
++:   // relax timing      
      tmp2   = (sinview_m * (hity_f - posy_f)) >>> $FPm$;
++:   // relax timing      
      dist_f = (tmp1 - tmp2);
++:   // relax timing      
      // projection divide
      (height) <- div <- ($lshift(140,FPf)$,dist_f>>1);
      
      columns.addr   = c;
      columns.wdata  = height;
      material.addr  = c;
      material.wdata = {v_or_h,2b0} | (hit-1);
      texcoord.addr  = c;
      if (v_or_h == 0) {
        texcoord.wdata = hity_f >>> $FPf-6$;
      } else {
        texcoord.wdata = hitx_f >>> $FPf-6$;
      }
      
      // write on loop
     
      c = c + 1;
    }
    
    // draw columns
    c = 0;
    columns.wenable  = 0;
    material.wenable = 0;
    texcoord.wenable = 0;
    while (c < 320) {
      columns.addr  = c;
      material.addr = c;
      texcoord.addr = c;
++:
      if (columns.rdata < 100) {
        h = columns.rdata;
      } else {
        h = 99;        
      }
      hscr_inv.addr = columns.rdata & 511;
      v_tex = $lshift(32,13)$;
++:      
      v_tex_incr    = hscr_inv.rdata;  
      y = 0;
      while (y < 100) {
        // floor and bottom half
        if (y <= h) {
          texture.addr = ((texcoord.rdata + ((material.rdata&3)<<6)) & 255) + (((v_tex >> 13) & 63)<<8);
++:          
          if (material.rdata[2,1] == 1) {
            palidx       = texture.rdata;
          } else {
            palidx       = texture.rdata + 64;
          }
        } else {
          palidx = 22;  
        }
        // write to sdram
        yw = 100+y;
        while (1) {
          if (sbusy == 0) { // not busy?
            sdata_in    = palidx;
            // saddr       = {~fbuffer,21b0} | ((c + (yw << 8) + (yw << 6)) >> 2); // * 240 / 4
            saddr       = {1b0,~fbuffer,21b0} | (c >> 2) | (yw << 8); 
            swbyte_addr = c & 3;
            sin_valid   = 1; // go ahead!
            break;
          }
        }          
        yw = 100-y;
        // floor and bottom half
        palidx = 22;  
        if (y <= h) {
          texture.addr = ((texcoord.rdata + (material.rdata<<6)) & 255) + ((63 - ((v_tex >> 13) & 63))<<8);
++:          
          if (material.rdata[2,1] == 1) {
            palidx       = texture.rdata;
          } else {
            palidx       = texture.rdata + 64;
          }
        } else {
          palidx = 2;
        }
        while (1) {
          if (sbusy == 0) { // not busy?
            sdata_in    = palidx;
            // saddr       = {~fbuffer,21b0} | ((c + (yw << 8) + (yw << 6)) >> 2); // * 240 / 4
            saddr       = {1b0,~fbuffer,21b0} | (c >> 2) | (yw << 8); 
            swbyte_addr = c & 3;
            sin_valid   = 1; // go ahead!
            break;
          }
        }
        if (y <= h) {
          v_tex = v_tex + v_tex_incr;
        }
        y = y + 1;        
      }      
      c = c + 1;
    }    
    
    // wait for frame to end
    while (vsync_filtered == 0) {}

    // swap buffers
    fbuffer = ~fbuffer;

  }

}

// ------------------------- 
