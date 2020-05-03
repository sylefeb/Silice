// SL 2020-04-28
// DoomChip!
//
// References:
// "DooM black book" by Fabien Sanglard
// DooM unofficial specs http://www.gamers.org/dhs/helpdocs/dmsp1666.html

$$print('main file')
$$texfile = 'doom.tga'
$$texfile_palette = get_palette_as_table(texfile,color_depth)

$include('../common/video_sdram_main.ice')

$$dofile('pre_load_data.lua')
$$dofile('pre_render_test.lua')

$$FPw = 30
$$FPm = 12

$$div_width = FPw
$include('../common/divint_any.ice')

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

  bram int$FPm+1$ sin_m[2048] = {
$$for i=0,2047 do
    $math.floor(0.5 + ((2^FPm)-1) * math.sin(2*math.pi*i/2048))$,
$$end
  };

  bram int13 coltoalpha[320] = {
$$for i=0,319 do
    $math.floor(0.5 + math.atan((320/2-i)*2/320) * (2^11) / (2*math.pi))$,
$$end
  };

  uint16 queue[16] = {};
  uint9  queue_ptr = 0;

  uint1  vsync_filtered = 0;
  
  int$FPw$ cosview_m  = 0;
  int$FPw$ sinview_m  = 0;
  int16    viewangle  = 512;
  int16    colangle   = 0;

$$if HARDWARE then
  int16    ray_x    =  1050;
  int16    ray_y    = -3616;
$$else
  int16    ray_x    =  1050;
  int16    ray_y    =$-3616+50*4$;
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
  int$FPw$ invd_m   = 0;
  int$FPw$ interp_m = 0;
  int$FPw$ tmp1_m   = 0;
  int$FPw$ tmp2_m   = 0;
  int16    h        = 0;
  int16    sec_f_h  = 0;
  int16    sec_c_h  = 0;
  int$FPw$ f_h      = 0;
  int$FPw$ c_h      = 0;
  int$FPw$ f_o      = 0;
  int$FPw$ c_o      = 0;
 
  div$FPw$ div;
  int$FPw$ num      = 0;
  int$FPw$ den      = 0;
 
  uint16   rchild   = 0;
  uint16   lchild   = 0;

  int10    top = 200;
  int10    btm = 1;
  uint9    c   = 0;
  uint9    j   = 0;

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
  
  sin_m.wenable      = 0;
  coltoalpha.wenable = 0;
  
  while (1) {

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
      
      coltoalpha.addr = c;
++:
      colangle = (viewangle + coltoalpha.rdata);

      // get ray dx/dy
      sin_m.addr = (colangle) & 2047;
++:    
      ray_dy_m   = sin_m.rdata;
      sin_m.addr = (colangle + 512) & 2047;
++:    
      ray_dx_m   = sin_m.rdata;

      // set sin table addr to get cos(alpha)
      sin_m.addr = (coltoalpha.rdata + 512) & 2047;
      
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
++:
            cs1_m = (d1y * ray_dx_m - d1x * ray_dy_m);
++:
            if ((cs0_m<0 && cs1_m>=0) || (cs1_m<0 && cs0_m>=0)) {
              // compute distance        
              y0_m  =  (  d0x * ray_dx_m + d0y * ray_dy_m );
++:
              y1_m  =  (  d1x * ray_dx_m + d1y * ray_dy_m );
++:
              x0_m  =  cs0_m;
              x1_m  =  cs1_m;
              // d  = y0 + (y0 - y1) * x0 / (x1 - x0)        
              num   = x0_m;
              den   = (x1_m - x0_m) >>> $FPm$;
              (interp_m) <- div <- (num,den);
              d_m   = y0_m + (((y0_m - y1_m) >>> $FPm$) * interp_m);
              if (d_m > 0) { // check sign
                // hit!
                // -> correct to perpendicular distance ( * cos(alpha) )
                tmp2_m = (d_m >> $FPm$) * sin_m.rdata;
                // -> compute inverse distance
                (invd_m) <- div <- ($(1<<16)-1$,(tmp2_m >> $FPm$)); // 1024 / d
                // -> get floor/ceiling heights
                sec_f_h = bsp_ssecs.rdata[24,16];
                sec_c_h = bsp_ssecs.rdata[40,16];
                tmp1_m  = (sec_f_h) * 30;
                tmp2_m  = (sec_c_h) * 30;
                f_h     = 100 + ((tmp1_m * invd_m) >>> 13);
                c_h     = 100 + ((tmp2_m * invd_m) >>> 13);
                if (btm > f_h) {
                  f_h = btm;
                } else { if (top < f_h) {
                  f_h = top;
                } }
                if (btm > c_h) {
                  c_h = btm;
                } else { if (top < c_h) {
                  c_h = top;
                } }
                // move floor
                while (btm < f_h) {                
                  () <- writePixel <- (c,btm,255);
                  btm = btm + 1;                  
                }
                // move ceiling
                while (top > c_h) {                
                  () <- writePixel <- (c,top,255);
                  top = top - 1;
                }
                // lower part?                
                if (bsp_segs_tex_height.rdata[32,8] != 0) {
                  sec_f_h   = bsp_segs_tex_height.rdata[0,16];
                  tmp1_m    = (sec_f_h)*$FPw$;
                  f_o       = 100 + ((tmp1_m * invd_m) >>> 13);
                  if (btm > f_o) {
                    f_o = btm;
                  } else { if (top < f_o) {
                    f_o = top;
                  } }
                  while (btm < f_o) {                
                    () <- writePixel <- (c,btm,(n&255));
                    btm = btm + 1;                  
                  }                  
                }
                // upper part?                
                if (bsp_segs_tex_height.rdata[48,8] != 0) {
                  sec_c_h   = bsp_segs_tex_height.rdata[16,16];
                  tmp1_m    = (sec_c_h)*$FPw$;
                  c_o       = 100 + ((tmp1_m * invd_m) >>> 13);
                  if (btm > c_o) {
                    c_o = btm;
                  } else { if (top < c_o) {
                    c_o = top;
                  } }
                  while (top > c_o) {                
                    () <- writePixel <- (c,top,(n&255));
                    top = top - 1;                  
                  }
                }
                if (bsp_segs_tex_height.rdata[40,8] != 0) {
                  // opaque wall
                  j = f_h;
                  while (j <= c_h) {                
                    () <- writePixel <- (c,j,(n&255));
                    j = j + 1;                  
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
$$if HARDWARE then
    ray_y = ray_y + 1;
$$else
    ray_y = ray_y + 4;
$$end
    if (ray_y > -3216) {
      ray_y = -3616;
    }
    
    // wait for frame to end
    while (vsync_filtered == 0) {}

    // swap buffers
    fbuffer = ~fbuffer;

  }

}

// ------------------------- 
