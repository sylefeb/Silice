// SL 2020-04-28
// DoomChip!
//
// References:
// "DooM black book" by Fabien Sanglard
// DooM unofficial specs http://www.gamers.org/dhs/helpdocs/dmsp1666.html

$$print('------< Compiling the DooM chip >------')
$$print('---< written in Silice by @sylefeb >---')

$$texfile = 'doom.tga'
$$texfile_palette = get_palette_as_table(texfile,color_depth)

$include('../common/video_sdram_main.ice')

$$dofile('pre_load_data.lua')
$$dofile('pre_render_test.lua')

// verilator does not like 64 bits ...
$$FPl = 48 
$$FPw = 24
$$FPm = 12

$$div_width = FPl
$include('../common/divint_any.ice')
$$mul_width = FPw
$include('../common/mulint_any.ice')

// -------------------------

$$function macro_to_h(iv,ov)
$$code = 
$$[[  // shift and round
$$    if (iv[14,1]) {
$$      ov = 101 + (iv >>> 15);
$$    } else {
$$      ov = 100 + (iv >>> 15);
$$    }
$$]]
$$code=code:gsub('iv', iv)
$$code=code:gsub('ov', ov)
$$return code
$$end

$$function macro_to_tex_v(iv,ov)
$$code = 
$$[[  // shift and round
$$    if (iv[6,1]) {
$$      ov = (iv >> 7) + 1;
$$    } else {
$$      ov = (iv >> 7);
$$    }
$$]]
$$code=code:gsub('iv', iv)
$$code=code:gsub('ov', ov)
$$return code
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

  subroutine writePixel(
     reads  sbusy,
     writes sdata_in,
     writes saddr,
     writes swbyte_addr,
     writes sin_valid,
     reads  fbuffer,
     input  uint9  pi,
     input  uint9  pj,
     input  uint8  value
     )
  {
    uint9 revpj = 0;
    revpj = 199 - pj;
    while (1) {
      if (sbusy == 0) { // not busy?
        sdata_in    = value;
        // saddr       = {~fbuffer,21b0} | ((pi + (revpj << 8) + (revpj << 6)) >> 2); // * 240 / 4
        saddr       = {~fbuffer,21b0} | (pi >> 2) | (revpj << 8);
        swbyte_addr = pi & 3;
        sin_valid   = 1; // go ahead!
        break;
      }
    }
    return;  
  }

  bram uint64 bsp_nodes_coords[] = {
$$for _,n in ipairs(bspNodes) do
   $pack_bsp_node_coords(n)$, // dy=$n.dy$ dx=$n.dx$ y=$n.y$ x=$n.x$
$$end
  };
  bram uint32 bsp_nodes_children[] = {
$$for _,n in ipairs(bspNodes) do
   $pack_bsp_node_children(n)$, // lchild=$n.lchild$ rchild=$n.rchild$ 
$$end
  };
  bram uint56 bsp_ssecs[] = {
$$for _,s in ipairs(bspSSectors) do
   $pack_bsp_ssec(s)$,          // c_h=$s.c_h$ f_h=$s.f_h$  start_seg=$s.start_seg$ num_segs=$s.num_segs$
$$end
  };
  bram uint64 bsp_segs_coords[] = {
$$for _,s in ipairs(bspSegs) do
   $pack_bsp_seg_coords(s)$, // v1y=$s.v1y$ v1x=$s.v1x$ v0y=$s.v0y$ v0x=$s.v0x$ 
$$end
  };
  bram uint56 bsp_segs_tex_height[] = {
$$for _,s in ipairs(bspSegs) do
   $pack_bsp_seg_tex_height(s)$, // upr=$s.upr$ mid=$s.mid$ lwr=$s.lwr$ other_c_h=$s.other_c_h$ other_f_h=$s.other_f_h$ 
$$end
  };
  bram uint32 bsp_segs_texmapping[] = {
$$for _,s in ipairs(bspSegs) do
   $pack_bsp_seg_texmapping(s)$, // off=$s.off$ seglen=$s.seglen$
$$end
  };
  bram uint24 demo_path[] = {
$$for _,s in ipairs(demo_path) do
   $pack_demo_path(s)$, // straight=$s.straight$ strafe=$s.strafe$ turn=$s.turn$
$$end
  };
  uint16 demo_path_len = $#demo_path$;

$$ sin_tbl = {}
$$ max_sin = ((2^FPm)-1)
$$for i=0,1023 do
$$   sin_tbl[i]        = round(max_sin*math.sin(2*math.pi*(i+0.5)/4096))
$$   sin_tbl[1024 + i] = round(math.sqrt(max_sin*max_sin - sin_tbl[i]*sin_tbl[i]))
$$   sin_tbl[2048 + i] = - sin_tbl[i]
$$   sin_tbl[2048 + 1024 + i] = - sin_tbl[1024 + i]
$$end
$$--for i=0,2047 do
$$--   print('sanity check: ' .. (math.sqrt(sin_tbl[i]*sin_tbl[i]+sin_tbl[i+1024]*sin_tbl[i+1024])))
$$--end

  bram int$FPm+1$ sin_m[4096] = {
$$for i=0,4095 do
    $sin_tbl[i]$,
$$end
  };

  bram int13 coltoalpha[320] = {
$$for i=0,319 do
    $round(math.atan((320/2-(i+0.5))*3/320) * (2^12) / (2*math.pi))$,
$$end
  };

  uint16 queue[16] = {};
  uint9  queue_ptr = 0;

  uint1  vsync_filtered = 0;
  
  int$FPw$ cosview_m  = 0;
  int$FPw$ sinview_m  = 0;
  int16    viewangle  = 1024;
  int16    colangle   = 0;

  int8     signed8    = 0;
  int16    frame      = 0;

  int24    demo_x    = $( 1050)<<3$;
  int24    demo_y    = $(-3616)<<3$;
  
$$if HARDWARE then
  int16    ray_x    =  1050;
  int16    ray_y    = -3616;
$$else
  int16    ray_x    =  1050;
  int16    ray_y    =$-3616$;
$$end
  int$FPw$ ray_dx_m = 0;
  int$FPw$ ray_dy_m = 0;
  int16    lx       = 0;
  int16    ly       = 0;
  int16    ldx      = 0;
  int16    ldy      = 0;
  int16    dx       = 0;
  int16    dy       = 0;
  int$FPw$ csl      = 0;
  int$FPw$ csr      = 0;
  int16    v0x      = 0;
  int16    v0y      = 0;
  int16    v1x      = 0;
  int16    v1y      = 0;
  int16    d0x      = 0;
  int16    d0y      = 0;
  int16    d1x      = 0;
  int16    d1y      = 0;
  int$FPw$ cs0_m    = 0;
  int$FPw$ cs1_m    = 0;
  int$FPw$ x0_m     = 0;
  int$FPw$ y0_m     = 0;
  int$FPw$ x1_m     = 0;
  int$FPw$ y1_m     = 0;
  int$FPw$ d_m      = 0;
  int$FPw$ invd_h   = 0;
  int$FPw$ interp_m = 0;
  int16    tmp1     = 0;
  int16    tmp2     = 0;
  int$FPw$ tmp1_m   = 0;
  int$FPw$ tmp2_m   = 0;
  int$FPl$ tmp1_h   = 0; // larger to hold FPm x FPm
  int$FPl$ tmp2_h   = 0; // larger to hold FPm x FPm
  int16    h        = 0;
  int$FPw$ sec_f_h  = 0;
  int$FPw$ sec_c_h  = 0;
  int$FPw$ sec_f_o  = 0;
  int$FPw$ sec_c_o  = 0;
  int$FPw$ f_h      = 0;
  int$FPw$ c_h      = 0;
  int$FPw$ f_o      = 0;
  int$FPw$ c_o      = 0;
  int$FPw$ tex_v    = 0;
 
  div$FPl$ divl;
  int$FPl$ num      = 0;
  int$FPl$ den      = 0;
  mul$FPw$ mull;
  int$FPw$ mula     = 0;
  int$FPw$ mulb     = 0;
  int$FPl$ mulr     = 0;
 
  uint16   rchild   = 0;
  uint16   lchild   = 0;

  int10    top = 200;
  int10    btm = 1;
  uint9    c   = 0;
  uint9    j   = 0;
  uint8    palidx = 0;

  uint9    s   = 0;  
  uint16   n   = 0;
  
  vsync_filtered ::= vsync;

  sin_valid := 0; // maintain low (pulses high when needed)
  
  srw = 1;        // sdram write

  fbuffer = 0;
  
  // brams in read mode
  bsp_nodes_coords   .wenable = 0;
  bsp_nodes_children .wenable = 0;
  bsp_ssecs          .wenable = 0;
  bsp_segs_coords    .wenable = 0;
  bsp_segs_tex_height.wenable = 0;
  demo_path          .wenable = 0;
  
  sin_m.wenable      = 0;
  coltoalpha.wenable = 0;
  
  while (1) {
  
    // update viewangle
    signed8   = demo_path.rdata[0,8];
    viewangle = viewangle + (signed8 <<< 3);

    // get cos/sin view
    sin_m.addr = (viewangle) & 4095;
++:    
    sinview_m  = sin_m.rdata;
    sin_m.addr = (viewangle + 1024) & 4095;
++:    
    cosview_m  = sin_m.rdata;

    // update position (demo runs at higher res)
    signed8 = demo_path.rdata[16,8];
    demo_x = demo_x + ((cosview_m * signed8) >>> $FPm$);
    demo_y = demo_y + ((sinview_m * signed8) >>> $FPm$);
++:
    signed8 = demo_path.rdata[8,8];
    demo_x = demo_x - ((sinview_m * signed8) >>> $FPm$);
    demo_y = demo_y + ((cosview_m * signed8) >>> $FPm$);
    
    ray_x  = demo_x >>> 3;
    ray_y  = demo_y >>> 3;
    
    // raycast columns
    c = 0;
    while (c < 320) { 
      
      coltoalpha.addr = c;
++:
      colangle = (viewangle + coltoalpha.rdata);

      // get ray dx/dy
      sin_m.addr = (colangle) & 4095;
++:    
      ray_dy_m   = sin_m.rdata;
      sin_m.addr = (colangle + 1024) & 4095;
++:    
      ray_dx_m   = sin_m.rdata;

      // set sin table addr to get cos(alpha)
      sin_m.addr = (coltoalpha.rdata + 1024) & 4095;
      
      top = 200;
      btm = 1;
      
      // init recursion
      queue[queue_ptr] = $root$;
      queue_ptr = 1;

      // let's rock!
      while (queue_ptr > 0) {
        queue_ptr = queue_ptr-1;
        n = queue[queue_ptr];

        bsp_nodes_coords  .addr = n;
        bsp_nodes_children.addr = n;
++:
        if (n[15,1] == 0) {
          // node
          lx  = bsp_nodes_coords.rdata[0 ,16];
          ly  = bsp_nodes_coords.rdata[16,16];
          ldx = bsp_nodes_coords.rdata[32,16];
          ldy = bsp_nodes_coords.rdata[48,16];
          // which side are we on?
          dx   = ray_x - lx;
          dy   = ray_y - ly;
++:
          csl  = (dx * ldy);
++:
          csr  = (dy * ldx);
          if (csr > csl) {
            // front
            queue[queue_ptr  ] = bsp_nodes_children.rdata[ 0,16];
            queue[queue_ptr+1] = bsp_nodes_children.rdata[16,16];
          } else {
            queue[queue_ptr  ] = bsp_nodes_children.rdata[16,16];
            queue[queue_ptr+1] = bsp_nodes_children.rdata[ 0,16];          
          }
          queue_ptr = queue_ptr + 2;          
        } else {
          // sub-sector reached
          bsp_ssecs.addr = n[0,14];
++:
          s = 0;
          while (s < bsp_ssecs.rdata[0,8]) {
            bsp_segs_coords.addr      = bsp_ssecs.rdata[8,16] + s;
            bsp_segs_tex_height.addr  = bsp_ssecs.rdata[8,16] + s;
            bsp_segs_texmapping.addr  = bsp_ssecs.rdata[8,16] + s;
++:
            v0x = bsp_segs_coords.rdata[ 0,16];
            v0y = bsp_segs_coords.rdata[16,16];
            v1x = bsp_segs_coords.rdata[32,16];
            v1y = bsp_segs_coords.rdata[48,16];
            // check for intersection
            d0x = v0x - ray_x;
            d0y = v0y - ray_y;
            d1x = v1x - ray_x;
            d1y = v1y - ray_y;
++:
            cs0_m = (d0y * ray_dx_m - d0x * ray_dy_m);
            cs1_m = (d1y * ray_dx_m - d1x * ray_dy_m);
++:
            if ((cs0_m<0 && cs1_m>=0) || (cs1_m<0 && cs0_m>=0)) {
              // compute distance        
              y0_m  =  (  d0x * ray_dx_m + d0y * ray_dy_m );
              y1_m  =  (  d1x * ray_dx_m + d1y * ray_dy_m );
++:
              x0_m  =  cs0_m;
              x1_m  =  cs1_m;
              // d  = y0 + (y0 - y1) * x0 / (x1 - x0)        
              num   = x0_m <<< $FPm$;
              den   = (x1_m - x0_m);
              (interp_m) <- divl <- (num,den);              
              // d_m   = y0_m + (((y0_m - y1_m) >>> $FPm$) * interp_m);
              mula  = (y0_m - y1_m);
              mulb  = interp_m;
              (mulr) <- mull <- (mula,mulb);
              // mulr  = mula * mulb;
              d_m   = y0_m + (mulr >>> $FPm$);
              
              if (d_m > $1<<(FPm+1)$) { // check sign, with margin to stay away from 0
              
                // hit!
                // -> correct to perpendicular distance ( * cos(alpha) )
                num     = $FPl$d$(1<<(2*FPm+FPw-2))$;
                den     = d_m * sin_m.rdata;
                // -> compute inverse distance
                (invd_h) <- divl <- (num,den); // (2^(FPw-2)) / d
                d_m     = den >>> $FPw$; // record corrected distance for tex. mapping
                // -> get floor/ceiling heights
                tmp1    = bsp_ssecs.rdata[24,16]; // NOTE: signed, so always read in same width!
                tmp2    = bsp_ssecs.rdata[40,16];
                tmp1_h  = (tmp1 * invd_h);
                tmp2_h  = (tmp2 * invd_h);
                // shift and round column heights
                $macro_to_h('tmp1_h','f_h')$
                $macro_to_h('tmp2_h','c_h')$                
                // shift sector heights for texturing
                tmp2_m  = (tmp1 <<< $FPm$);
                sec_f_h = tmp2_m;
                if (btm > f_h) {
                  sec_f_h = tmp2_m + ((btm - f_h) * d_m); // offset texturing
                  f_h     = btm;
                } else { if (top < f_h) {
                  sec_f_h = tmp2_m + ((top - f_h) * d_m); // offset texturing
                  f_h     = top;
                } }
                if (btm > c_h) {
                  c_h     = btm;
                } else { if (top < c_h) {
                  c_h     = top;
                } }

                ///
                palidx = (n&255);
                // palidx = bsp_segs_texmapping.rdata[16,16] + ( (bsp_segs_texmapping.rdata[0,16] * interp_m) >> $FPm$);               

                // draw floor
                while (btm < f_h) {                
                  () <- writePixel <- (c,btm,255);
                  btm = btm + 1;                  
                }
                // draw ceiling
                while (top > c_h) {                
                  () <- writePixel <- (c,top,255);
                  top = top - 1;
                }

                // lower part?                
                if (bsp_segs_tex_height.rdata[32,8] != 0) {
                  tmp1      = bsp_segs_tex_height.rdata[0,16];
                  tmp1_h    = (tmp1 * invd_h);
                  tmp2_m    = tmp1 <<< $FPm$;
                  sec_f_o   = tmp2_m;
                  $macro_to_h('tmp1_h','f_o')$ // shift and round
                  if (btm > f_o) {
                    sec_f_o = tmp2_m + ((btm - f_o) * d_m); // offset texturing
                    f_o     = btm;
                  } else { if (top < f_o) {
                    sec_f_o = tmp2_m + ((top - f_o) * d_m); // offset texturing
                    f_o     = top;
                  } }
                  tex_v   = sec_f_o;
                  while (btm < f_o) {
                    $macro_to_tex_v('tex_v','palidx')$
                    () <- writePixel <- (c,btm,(palidx));
                    btm = btm + 1;  
                    tex_v = tex_v + d_m;
                  }                  
                }
                // upper part?                
                if (bsp_segs_tex_height.rdata[48,8] != 0) {
                  tmp1      = bsp_segs_tex_height.rdata[16,16];
                  tmp1_h    = (tmp1 * invd_h);
                  tmp2_m    = tmp1 <<< $FPm$;
                  sec_c_o   = tmp2_m;
                  $macro_to_h('tmp1_h','c_o')$ // shift and round
                  if (btm > c_o) {
                    sec_c_o = tmp2_m - ((btm - c_o) * d_m); // offset texturing
                    c_o     = btm;
                  } else { if (top < c_o) {
                    sec_c_o = tmp2_m - ((top - c_o) * d_m); // offset texturing
                    c_o     = top;
                  } }
                  tex_v   = sec_c_o;
                  while (top > c_o) {                
                    $macro_to_tex_v('tex_v','palidx')$
                    () <- writePixel <- (c,top,(palidx));
                    top = top - 1;     
                    tex_v = tex_v - d_m;
                  }
                }
                if (bsp_segs_tex_height.rdata[40,8] != 0) {
                  // opaque wall
                  tex_v   = sec_f_h;
                  j       = f_h;
                  while (j <= c_h) {                
                    $macro_to_tex_v('tex_v','palidx')$
                    () <- writePixel <- (c,j,(palidx));
                    j = j + 1;   
                    tex_v = tex_v + d_m;
                  }
                  // flush queue to stop
                  queue_ptr = 0;
                  break;                 
                }
              }
            }
            // next segment
            s = s + 1;            
          }
        }
        
      }

      // next column    
      c = c + 1;
    }
    
    // prepare next
    frame = frame + 1;
    if (frame >= demo_path_len) {
      frame = 0;
    }
    
    demo_path.addr = frame;
    
    // wait for frame to end
    while (vsync_filtered == 0) {}

    // swap buffers
    fbuffer = ~fbuffer;

  }

}

// ------------------------- 
