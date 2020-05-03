// SL 2020-04-28
// DoomChip!
//
// References:
// "DooM black book" by Fabien Sanglard
// DooM unofficial specs http://www.gamers.org/dhs/helpdocs/dmsp1666.html

$$print('main file')
$$-- texfile = 'doom.tga'
$$-- texfile_palette = get_palette_as_table(texfile,color_depth)

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
  bram uint32 bsp_segs_texmapping[] = {
$$for _,s in ipairs(bspSegs) do
   $pack_bsp_seg_texmapping(s)$, // off=$s.off$ seglen=$s.seglen$
$$end
  };

  bram int$FPm+1$ sin_m[4096] = {
$$for i=0,4095 do
    $math.floor(0.5 + ((2^FPm)-1) * math.sin(2*math.pi*(i+0.5)/4096))$,
$$end
  };

  bram int13 coltoalpha[320] = {
$$for i=0,319 do
    $math.floor(0.5 + math.atan((320/2-(i+0.5))*3/320) * (2^12) / (2*math.pi))$,
$$end
  };

  uint16 queue[16] = {};
  uint9  queue_ptr = 0;

  uint1  vsync_filtered = 0;
  
  int$FPw$ cosview_m  = 0;
  int$FPw$ sinview_m  = 0;
  int16    viewangle  = 1024;
  int16    colangle   = 0;

$$if HARDWARE then
  int16    ray_x    =  1050;
  int16    ray_y    = -3616;
$$else
  int16    ray_x    =  1050;
  int16    ray_y    =$-3616 + 90$;
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
  int$FPw$ tmp1_m   = 0;
  int$FPw$ tmp2_m   = 0;
  int$FPw$ tmp1     = 0;
  int$FPw$ tmp2     = 0;
  int16    h        = 0;
  int16    sec_f_h  = 0;
  int16    sec_c_h  = 0;
  int16    sec_f_o  = 0;
  int16    sec_c_o  = 0;
  int$FPw$ f_h      = 0;
  int$FPw$ c_h      = 0;
  int$FPw$ f_o      = 0;
  int$FPw$ c_o      = 0;
  int$FPw$ tex_v    = 0;
 
  div$FPw$ div;
  int$FPw$ num      = 0;
  int$FPw$ den      = 0;
 
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
  
  sin_m.wenable      = 0;
  coltoalpha.wenable = 0;
  
  while (1) {

    // get cos/sin view
    sin_m.addr = (viewangle) & 4095;
++:    
    sinview_m  = sin_m.rdata;
    sin_m.addr = (viewangle + 1024) & 4095;
++:    
    cosview_m  = sin_m.rdata;

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
              if (d_m > $1<<(FPm+1)$) { // check sign, with margin to stay away from 0
                // hit!
                // -> correct to perpendicular distance ( * cos(alpha) )
                tmp2_m = (d_m >> $FPm$) * sin_m.rdata;
                // -> compute inverse distance
                (invd_h) <- div <- ($(1<<24)-1$,(tmp2_m >> $FPm$)); // 1 / d
                d_m     = tmp2_m; // record corrected distance for tex. mapping
                // -> get floor/ceiling heights
                sec_f_h = bsp_ssecs.rdata[24,16];
                sec_c_h = bsp_ssecs.rdata[40,16];
                tmp1    = (sec_f_h * invd_h);
                tmp2    = (sec_c_h * invd_h);
                
                // TODO: round!
                if (tmp1>0) {
                  if (tmp1[16,1]) {
                    f_h   = 101 + (tmp1 >>> 17);
                  } else {
                    f_h   = 100 + (tmp1 >>> 17);
                  }
                } else {
                  if (tmp1[16,1]) {
                    f_h   = 100 + (tmp1 >>> 17);
                  } else {
                    f_h   =  99 + (tmp1 >>> 17);
                  }
                }
                
                if (tmp2>0) {
                  if (tmp2[16,1]) {
                    c_h   = 101 + (tmp2 >>> 17);
                  } else {
                    c_h   = 100 + (tmp2 >>> 17);
                  }
                } else {
                  if (tmp1[16,1]) {
                    c_h   = 100 + (tmp2 >>> 17);
                  } else {
                    c_h   =  99 + (tmp2 >>> 17);
                  }
                }
                
                //f_h     = 100 + (tmp1 >>> 17);
                //c_h     = 100 + (tmp2 >>> 17);
                
                ///
                palidx = (n&255);
                // palidx = bsp_segs_texmapping.rdata[16,16] + ( (bsp_segs_texmapping.rdata[0,16] * interp_m) >> $FPm$);
                
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
                  sec_f_o   = bsp_segs_tex_height.rdata[0,16];
                  tmp1      = (sec_f_o*invd_h);
                  //f_o       = 100 + ((tmp1 * invd_h) >>> 17);
                  
                  if (tmp1>0) {
                    if (tmp1[16,1]) {
                      f_o   = 101 + (tmp1 >>> 17);
                    } else {
                      f_o   = 100 + (tmp1 >>> 17);
                    }
                  } else {
                    if (tmp1[16,1]) {
                      f_o   = 100 + (tmp1 >>> 17);
                    } else {
                      f_o   =  99 + (tmp1 >>> 17);
                    }
                  }
                  
                  if (btm > f_o) {
                    f_o = btm;
                  } else { if (top < f_o) {
                    f_o = top;
                  } }
                  tex_v   = sec_f_o << 16;
                  while (btm < f_o) {                
                    () <- writePixel <- (c,btm,(tex_v>>19));
                    btm = btm + 1;  
                    tex_v = tex_v + d_m;
                  }                  
                }
                // upper part?                
                if (bsp_segs_tex_height.rdata[48,8] != 0) {
                  sec_c_o   = bsp_segs_tex_height.rdata[16,16];
                  tmp1      = (sec_c_o*invd_h);
                  //c_o       = 100 + ((tmp1 * invd_h) >>> 17);
                  
                  if (tmp1>0) {
                    if (tmp1[16,1]) {
                      c_o   = 101 + (tmp1 >>> 17);
                    } else {
                      c_o   = 100 + (tmp1 >>> 17);
                    }
                  } else {
                    if (tmp1[16,1]) {
                      c_o   = 100 + (tmp1 >>> 17);
                    } else {
                      c_o   =  99 + (tmp1 >>> 17);
                    }
                  }
                  
                  if (btm > c_o) {
                    c_o = btm;
                  } else { if (top < c_o) {
                    c_o = top;
                  } }
                  tex_v   = sec_c_o << 16;
                  while (top > c_o) {                
                    () <- writePixel <- (c,top,(tex_v>>19));
                    top = top - 1;     
                    tex_v = tex_v - d_m;
                  }
                }
                if (bsp_segs_tex_height.rdata[40,8] != 0) {
                  // opaque wall
                  tex_v   = sec_f_h << 16;
                  j       = f_h;
                  while (j <= c_h) {                
                    () <- writePixel <- (c,j,(tex_v>>19));
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
$$if HARDWARE then
    ray_y = ray_y + 1;
$$else
    ray_y = ray_y + 10;
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
