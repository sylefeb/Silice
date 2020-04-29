// SL 2020-04-24
// Wolf3D!
//
// References:
// "DooM black book" by Fabien Sanglard
// DooM unofficial specs http://www.gamers.org/dhs/helpdocs/dmsp1666.html

$$print('main file')
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
// read sidedefs
$$ sides = {}
$$ local in_sides = assert(io.open('SIDEDEFS', 'rb'))
$$ local sz = fsize(in_sides)
$$ print('sidedefs file is ' .. sz .. ' bytes')
$$ for i = 1,sz/30 do
$$   local xoff = string.unpack('h',in_sides:read(2))
$$   local yoff = string.unpack('h',in_sides:read(2))
$$   local uprT = in_sides:read(8)
$$   local lwrT = in_sides:read(8)
$$   local midT = in_sides:read(8)
$$   local sec  = string.unpack('H',in_sides:read(2))
$$   sides[i] = {xoff = xoff, yoff = yoff,uprT = uprT,lwrT = lwrT, midT = midT, sec=sec}
$$ end
$$ for i,si in ipairs(sides) do
$$   print('sidedef ' .. i .. ' uprT:' .. si.uprT .. ' lwrT:' .. si.lwrT .. ' midT:' .. si.midT .. ' sec: ' .. (1+si.sec))
$$ end
// read sectors
$$ sectors = {}
$$ local in_sectors = assert(io.open('SECTORS', 'rb'))
$$ local sz = fsize(in_sectors)
$$ print('sectors file is ' .. sz .. ' bytes')
$$ for i = 1,sz/26 do
$$   local floor    = string.unpack('h',in_sectors:read(2))
$$   local ceiling  = string.unpack('h',in_sectors:read(2))
$$   local floorT   = in_sectors:read(8)
$$   local ceilingT = in_sectors:read(8)
$$   local light    = string.unpack('H',in_sectors:read(2))
$$   local special  = string.unpack('H',in_sectors:read(2))
$$   local tag      = string.unpack('H',in_sectors:read(2))
$$   sectors[i] = { floor=floor, ceiling=ceiling, floorT=floorT, ceilingT=ceilingT, light=light, special=special, tag=tag}
$$ end
$$ for i,s in ipairs(sectors) do
$$   print('sector ' .. i)
$$   for k,v in pairs(s) do
$$     print('   ' .. k .. ' = ' .. v)
$$   end
$$ end
// read linedefs
$$ lines = {}
$$ local in_lines = assert(io.open('LINEDEFS', 'rb'))
$$ local sz = fsize(in_lines)
$$ print('linedefs file is ' .. sz .. ' bytes')
$$ for i = 1,sz/14 do
$$   local v0    = string.unpack('H',in_lines:read(2))
$$   local v1    = string.unpack('H',in_lines:read(2))
$$   local flags = string.unpack('H',in_lines:read(2))
$$   local types = string.unpack('H',in_lines:read(2))
$$   local tag   = string.unpack('H',in_lines:read(2))
$$   local right = string.unpack('H',in_lines:read(2)) -- sidedef
$$   local left  = string.unpack('H',in_lines:read(2)) -- sidedef
$$   lines[i] = {v0 = v0, v1 = v1,flags = flags,types = types, tag = tag,right =right, left = left}
$$ end
$$ for _,ld in ipairs(lines) do
$$   print('right:' .. ld.right .. ' left:' .. ld.left)
$$ end
// read segs
$$ segs = {}
$$ local in_segs = assert(io.open('SEGS', 'rb'))
$$ local sz = fsize(in_segs)
$$ print('segs file is ' .. sz .. ' bytes')
$$ for i = 1,sz/12 do
$$   local v0  = string.unpack('H',in_segs:read(2))
$$   local v1  = string.unpack('H',in_segs:read(2))
$$   local agl = string.unpack('h',in_segs:read(2))
$$   local ldf = string.unpack('H',in_segs:read(2))
$$   local dir = string.unpack('h',in_segs:read(2))
$$   local off = string.unpack('h',in_segs:read(2))
$$   segs[i] = {v0=v0,v1=v1,agl=agl,ldf=ldf,dir=dir,off=off}
$$ end
$$ for _,s in ipairs(segs) do
$$ --  print('v0 = ' .. s.v0 .. ', v1 = ' .. s.v1)
$$ --  print('agl = ' .. s.agl .. ', linedef = ' .. s.ldf)
$$ --  print('dir = ' .. s.dir .. ', off = ' .. s.off)
$$ end
// read ssectors
$$ ssectors = {}
$$ local in_ssectors = assert(io.open('SSECTORS', 'rb'))
$$ local sz = fsize(in_ssectors)
$$ print('ssectors file is ' .. sz .. ' bytes')
$$ for i = 1,sz/4 do
$$   local num_segs  = string.unpack('H',in_ssectors:read(2))
$$   local start_seg = string.unpack('H',in_ssectors:read(2))
$$   ssectors[i] = {num_segs=num_segs,start_seg=start_seg}
$$ end
$$ for _,ss in ipairs(ssectors) do
$$ --  print('num_segs = ' .. ss.num_segs .. ', start_seg = ' .. ss.start_seg)
$$ end
// read nodes
$$ nodes = {}
$$ local in_nodes = assert(io.open('NODES', 'rb'))
$$ local sz = fsize(in_nodes)
$$ print('nodes file is ' .. sz .. ' bytes')
$$ root = sz/28 - 1
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
$$   local rchild = string.unpack('H',in_nodes:read(2))
$$   local lchild = string.unpack('H',in_nodes:read(2))
$$   nodes[i] = {x=x,y=y,dx=dx,dy=dy,
$$               rby_up=rby_up,rby_dw=rby_dw,rbx_dw=rbx_dw,rbx_up=rbx_up,
$$               lby_up=lby_up,lby_dw=lby_dw,lbx_dw=lbx_dw,lbx_up=lbx_up,
$$               rchild=rchild,lchild=lchild}
$$ end
$$ for _,n in ipairs(nodes) do
$$   --print('x = ' .. n.x .. ', y = ' .. n.y)
$$   --print('dx = ' .. n.dx .. ', dy = ' .. n.dy)
$$   --print('rchild = ' .. n.rchild .. ', lchild = ' .. n.lchild)
$$ end
// dump node lines for visualization
$$ local flines = io.open('lines.gcode','w')
$$ e = 0.0
$$ flines:write('G1 Z0.2\n')
$$ for _,n in ipairs(nodes) do
$$   flines:write('G1 X'..(n.x/100.0)..' Y'..(n.y/100.0)..' F1200\n')
$$   e = e + math.sqrt(n.dx*n.dx+n.dy*n.dy)/1000.0
$$   flines:write('G1 X'..((n.x+n.dx)/100.0)..' Y'..((n.y+n.dy)/100.0)..' E' .. e .. ' F1200\n')
$$ end
// some testing
$$ w = 320
$$ h = 200
$$ img = {}
$$ for j=1,h do
$$ img[j] = {}
$$ for i=1,w do
$$   img[j][i] = 0
$$ end
$$ end
// raycast
$$ ray_x   = 1050
$$ ray_y   = -3616+100
$$ view_dx = 0
$$ view_dy = 1
$$ for i=1,w do
$$   print('column ' .. i)
$$   ray_dx = (i-160)*4
$$   ray_dy = 320
$$   top    = 200
$$   btm    = 1
$$   len    = math.sqrt(ray_dx*ray_dx+ray_dy*ray_dy)
$$   ray_dx = ray_dx / len -- cos(angle)
$$   ray_dy = ray_dy / len -- sin(angle)
$$   queue = {}
$$   queue_ptr = 1
$$   queue[queue_ptr] = root
$$   queue_ptr = queue_ptr + 1
$$   while queue_ptr > 1 do
$$      n = queue[queue_ptr-1]
$$      queue_ptr = queue_ptr - 1
$$      if (n&(1<<15)) == 0 then
$$        lx  = nodes[1+n].x
$$        ly  = nodes[1+n].y
$$        ldx = nodes[1+n].dx
$$        ldy = nodes[1+n].dy
$$        r   = nodes[1+n].rchild
$$        l   = nodes[1+n].lchild
$$        -- which side are we?
$$        dx     = ray_x - lx
$$        dy     = ray_y - ly
$$        csl    = dx * ldy
$$        csr    = dy * ldx
$$        if csr > csl then
$$          -- front
$$          queue[queue_ptr] = nodes[1+n].rchild;
$$          queue_ptr = queue_ptr + 1     
$$          queue[queue_ptr] = nodes[1+n].lchild;
$$          queue_ptr = queue_ptr + 1     
$$        else
$$          -- back
$$          queue[queue_ptr] = nodes[1+n].lchild;
$$          queue_ptr = queue_ptr + 1     
$$          queue[queue_ptr] = nodes[1+n].rchild;
$$          queue_ptr = queue_ptr + 1     
$$        end
$$      else
$$        sec = (n&(~(1<<15)))
$$        -- print('sector ' .. sec)
$$        for s=0,ssectors[1+sec].num_segs-1 do
$$          sid = 1 + ssectors[1+sec].start_seg + s
$$          seg = segs[sid]
$$          v0  = verts[1+seg.v0]
$$          v1  = verts[1+seg.v1]
$$          -- print('seg id=' .. sid .. ' ' .. v0.x ..',' .. v0.y .. ' to ' .. v1.x .. ',' .. v1.y)
$$          -- check if solid
$$          ldef = lines[1+seg.ldf]
$$          other_sidedef = nil
$$          if seg.dir == 0 then
$$            sidedef   = sides[1+ldef.right]
$$            sidedefid = ldef.right
$$            if ldef.left < 65535 then
$$              other_sidedef = sides[1+ldef.left]
$$            end
$$          else
$$            sidedef = sides[1+ldef.left]
$$            sidedefid = ldef.left
$$            other_sidedef = sides[1+ldef.right]
$$          end
$$          -- check for intersection
$$          d0x = v0.x - ray_x
$$          d0y = v0.y - ray_y
$$          d1x = v1.x - ray_x
$$          d1y = v1.y - ray_y
$$          cs0 = d0x*ray_dy - d0y*ray_dx
$$          cs1 = d1x*ray_dy - d1y*ray_dx
$$          if (cs0<0 and cs1>=0) or (cs1<0 and cs0>=0) then
$$            -- compute distance
$$            y0 =    d0x * ray_dx + d0y * ray_dy
$$            y1 =    d1x * ray_dx + d1y * ray_dy
$$            x0 =  - d0x * ray_dy + d0y * ray_dx
$$            x1 =  - d1x * ray_dy + d1y * ray_dx
$$            d  = y0 + (y1 - y0) * ( - x0 ) / (x1 - x0)
$$            d  = d * (ray_dx*view_dx + ray_dy*view_dy) -- cos(alpha)
$$            if d > 0 then
$$              sector  = sectors[1+sidedef.sec]
$$              other_sector = nil
$$              if other_sidedef then
$$                other_sector = sectors[1+other_sidedef.sec]
$$              end
$$              -- hit!
$$              if (cs0<0 and cs1>=0) then orient = '+' else orient = '-' end
$$              print('hit! sidedef ' .. 1+sidedefid .. ' sector ' .. (1+sidedef.sec) .. ' seg.dir = ' .. seg.dir .. ' orient: ' .. orient)
$$              f_h     = (sector.floor   - 40) * 128
$$              c_h     = (sector.ceiling - 40) * 128
$$              f_h     = 100 + f_h / d
$$              c_h     = 100 + c_h / d
$$              f_h     = math.floor(math.max(btm,math.min(top,f_h)))
$$              c_h     = math.floor(math.max(btm,math.min(top,c_h)))
$$              -- move floor and ceiling
$$              for j=btm,f_h-1 do
$$                img[201-j][i] = 255
$$              end
$$              btm = f_h
$$              for j=c_h+1,top do
$$                img[201-j][i] = 255
$$              end
$$              top = c_h
$$              if sidedef.lwrT:sub(1, 1) ~= '-' then
$$                f_o = (other_sector.floor - 40) * 128
$$                f_o = 100 + f_o / d
$$                f_o = math.floor(math.max(btm,math.min(top,f_o)))
$$                for j=btm,f_o-1 do
$$                  img[201-j][i] = ((sid*173)&255) | (((sid*13)&255)<<8) | (((sid*7133)&255)<<16)
$$                end
$$                btm = f_o
$$              end
$$              if sidedef.uprT:sub(1, 1) ~= '-' then
$$                c_o = (other_sector.ceiling - 40) * 128
$$                c_o = 100 + c_o / d
$$                c_o = math.floor(math.max(btm,math.min(top,c_o)))
$$                for j=c_o+1,top do
$$                  img[201-j][i] = ((sid*173)&255) | (((sid*13)&255)<<8) | (((sid*7133)&255)<<16)
$$                end
$$                top = c_o
$$              end
$$              if sidedef.midT:sub(1, 1) ~= '-' then
$$                -- opaque wall
$$                for j=f_h,c_h do
$$                  img[201-j][i] = ((sid*173)&255) | (((sid*13)&255)<<8) | (((sid*7133)&255)<<16)
$$                end
$$                -- flush queue to stop
$$                queue_ptr = 1
$$                break
$$              end
$$            end
$$          end
$$        end
$$      end
$$   end
$$ end
$$ save_table_as_image(img,'test.tga')
$$ error('stop')

// pos    = vec3(1050, 30, -3616);
// target = vec3(1050, 30, -3500);

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
