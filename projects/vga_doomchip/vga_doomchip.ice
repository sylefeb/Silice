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

$$FPw = 32
$$FPf = 16
$$FPm = 16

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
    $math.floor((2^FPm) * math.sin(2*math.pi*i/2048))$,
$$end
  };

  bram int13 coltoalpha[320] = {
$$for i=0,319 do
    $math.floor(0.5 + math.atan((w/2-i)*2/w) * (2^12))$,
$$end
  };

  uint16 queue[64] = {};
  uint6  queue_ptr = 0;

  uint1  vsync_filtered = 0;

  div$FPw$ div;
  
  uint9 c = 0;

  int$FPw$ cosview_m  = 0;
  int$FPw$ sinview_m  = 0;
  int16    viewangle  = 0;
  int16    colangle   = 0;

  int$FPw$ ray_x_f  = $lshift( 1050,FPf)$;
  int$FPw$ ray_y_f  = $lshift(-3616,FPf)$;
  int$FPw$ ray_dx_m = 0;
  int$FPw$ ray_dy_m = 0;
  int$FPw$ lx_f     = 0;
  int$FPw$ ly_f     = 0;
  int$FPw$ ldx_f    = 0;
  int$FPw$ ldy_f    = 0;
  int$FPw$ dx_f     = 0;
  int$FPw$ dy_f     = 0;
  int$FPw$ csl_f    = 0;
  int$FPw$ csr_f    = 0;
  
  uint16   rchild   = 0;
  uint16   lchild   = 0;
  
  
  int9     top = 200;
  int9     btm =   1;
  uint16   n   =   0;
  
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
          lx_f  = bsp_nodes_coords.rdata[0 ,16];
          ly_f  = bsp_nodes_coords.rdata[16,16];
          ldx_f = bsp_nodes_coords.rdata[32,16];
          ldy_f = bsp_nodes_coords.rdata[48,16];
          // which side are we on?
          dx_f   = ray_x_f - lx_f;
          dy_f   = ray_y_f - ly_f;
          csl_f  = (dx_f * ldy_f) >>> $FPf$;
          csr_f  = (dy_f * ldx_f) >>> $FPf$;
          if (csr_f > csl_f) {
            // front
            queue[queue_ptr+1] = bsp_nodes_children.rdata[0,16];
            queue[queue_ptr+2] = bsp_nodes_children.rdata[16,16];
            queue_ptr          = queue_ptr + 2
          } else {
          
          }
          
        } else {
          // sub-sector reached
          
        }
        
      }

      // next column    
      c = c + 1;
    }
    
    // wait for frame to end
    while (vsync_filtered == 0) {}

    // swap buffers
    fbuffer = ~fbuffer;

  }

}

// ------------------------- 
