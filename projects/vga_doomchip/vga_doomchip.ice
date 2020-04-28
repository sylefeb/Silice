// SL 2020-04-24
// Wolf3D!
//
// References:
// "DooM black book" by Fabien Sanglard
// DooM unofficial specs http://www.gamers.org/dhs/helpdocs/dmsp1666.html

$$texfile = 'doom.tga'
$$texfile_palette = get_palette_as_table(texfile,color_depth)

$include('../common/video_sdram_main.ice')

$$FPw = 30
$$FPf = 12 -- fractions precision
$$FPm = 12 -- precision within cells

$$div_width = FPw
$include('../common/divint_any.ice')

// helper for file size
$$function fsize(file)
$$  local start = file:seek()
$$  local size  = file:seek("end")
$$  file:seek("set", start)
$$  return size
$$end
// read vertices
$$ verts = {}
$$ local in_verts = assert(io.open('VERTEXES', 'rb'))
$$ local sz = fsize(in_verts)
$$ print('vertex file is ' .. sz .. ' bytes')
$$ for i = 1,sz/4 do
$$   local x = string.unpack('h',in_verts:read(2))
$$   local y = string.unpack('h',in_verts:read(2))
$$   verts[i] = {x = x, y = y}
$$ end
$$ for _,v in ipairs(verts) do
$$   print('v = ' .. v.x .. ',' .. v.y)
$$ end
// read segs
$$ segs = {}
$$ local in_segs = assert(io.open('SEGS', 'rb'))
$$ local sz = fsize(in_segs)
$$ print('segs file is ' .. sz .. ' bytes')
$$ for i = 1,sz/12 do
$$   local v0  = string.unpack('h',in_segs:read(2))
$$   local v1  = string.unpack('h',in_segs:read(2))
$$   local agl = string.unpack('h',in_segs:read(2))
$$   local ldf = string.unpack('h',in_segs:read(2))
$$   local dir = string.unpack('h',in_segs:read(2))
$$   local off = string.unpack('h',in_segs:read(2))
$$   segs[i] = {v0=v0,v1=v1,agl=agl,ldf=ldf,dir=dir,off=off}
$$ end
$$ for _,s in ipairs(segs) do
$$   print('v0 = ' .. s.v0 .. ', v1 = ' .. s.v1)
$$   print('agl = ' .. s.agl .. ', linedef = ' .. s.ldf)
$$   print('dir = ' .. s.dir .. ', off = ' .. s.off)
$$ end
// read ssectors
$$ ssectors = {}
$$ local in_ssectors = assert(io.open('SSECTORS', 'rb'))
$$ local sz = fsize(in_ssectors)
$$ print('ssectors file is ' .. sz .. ' bytes')
$$ for i = 1,sz/4 do
$$   local num_segs  = string.unpack('h',in_ssectors:read(2))
$$   local start_seg = string.unpack('h',in_ssectors:read(2))
$$   ssectors[i] = {num_segs=num_segs,start_seg=start_seg}
$$ end
$$ for _,ss in ipairs(ssectors) do
$$   print('num_segs = ' .. ss.num_segs .. ', start_seg = ' .. ss.start_seg)
$$ end
// read nodes
$$ nodes = {}
$$ local in_nodes = assert(io.open('NODES', 'rb'))
$$ local sz = fsize(in_nodes)
$$ print('nodes file is ' .. sz .. ' bytes')
$$ for i = 1,sz/28 do
$$   local x  = string.unpack('h',in_nodes:read(2)) 
$$   local y  = string.unpack('h',in_nodes:read(2)) 
$$   local dx = string.unpack('h',in_nodes:read(2)) 
$$   local dy = string.unpack('h',in_nodes:read(2)) 
$$   local rby_up = string.unpack('h',in_nodes:read(2)) 
$$   local rby_dw = string.unpack('h',in_nodes:read(2)) 
$$   local rbx_dw = string.unpack('h',in_nodes:read(2)) 
$$   local rbx_up = string.unpack('h',in_nodes:read(2)) 
$$   local lby_up = string.unpack('h',in_nodes:read(2)) 
$$   local lby_dw = string.unpack('h',in_nodes:read(2)) 
$$   local lbx_dw = string.unpack('h',in_nodes:read(2)) 
$$   local lbx_up = string.unpack('h',in_nodes:read(2))
$$   local rchild = string.unpack('h',in_nodes:read(2))
$$   local lchild = string.unpack('h',in_nodes:read(2))
$$   nodes[i] = {x=x,y=y,dx=dx,dy=dy,
$$               rby_up=rby_up,rby_dw=rby_dw,rbx_dw=rbx_dw,rbx_up=rbx_up,
$$               lby_up=lby_up,lby_dw=lby_dw,lbx_dw=lbx_dw,lbx_up=lbx_up,
$$               rchild=rchild,lchild=lchild}
$$ end
$$ for _,n in ipairs(nodes) do
$$   print('x = ' .. n.x .. ', n.y = ' .. n.y)
$$   print('dx = ' .. n.dx .. ', n.dy = ' .. n.dy)
$$   print('rchild = ' .. n.rchild .. ', lchild = ' .. n.lchild)
$$ end


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

  div$FPw$ div;
  
  uint9 c = 0;
  
  vsync_filtered ::= vsync;

  sin_valid := 0; // maintain low (pulses high when needed)
  
  srw = 1;        // sdram write

  fbuffer = 0;
  
  while (1) {

    // raycast columns
    c = 0;
    while (c < 320) { 
      
      c = c + 1;
    }
    
    // draw columns
    
    // wait for frame to end
    while (vsync_filtered == 0) {}

    // swap buffers
    fbuffer = ~fbuffer;

  }

}

// ------------------------- 
