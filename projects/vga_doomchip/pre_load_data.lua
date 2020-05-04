-- SL 2020-04-30

-- -------------------------------------
-- helper for file size
function fsize(file)
  local start = file:seek()
  local size  = file:seek("end")
  file:seek("set", start)
  return size
end
-- helper for sorting
-- see https://stackoverflow.com/questions/2038418/associatively-sorting-a-table-by-value-in-lua
function getKeysSortedByValue(tbl, sortFunction)
  local keys = {}
  for key in pairs(tbl) do
    table.insert(keys, key)
  end
  table.sort(keys, function(a, b)
    return sortFunction(tbl[a], tbl[b])
  end)
  return keys
end

-- -------------------------------------
-- rounding
function round(x)
  return math.floor(x+0.5)
end

-- -------------------------------------
-- read vertices
verts = {}
local in_verts = assert(io.open(findfile('VERTEXES'), 'rb'))
local sz = fsize(in_verts)
print('vertex file is ' .. sz .. ' bytes')
for i = 1,sz/4 do
  local x = string.unpack('h',in_verts:read(2))
  local y = string.unpack('h',in_verts:read(2))
  verts[i] = {x = x, y = y}
end

-- -------------------------------------
-- read sidedefs, also gather textures
sides = {}
textures = {}
local in_sides = assert(io.open(findfile('SIDEDEFS'), 'rb'))
local sz = fsize(in_sides)
print('sidedefs file is ' .. sz .. ' bytes')
for i = 1,sz/30 do
  local xoff = string.unpack('h',in_sides:read(2))
  local yoff = string.unpack('h',in_sides:read(2))
  local uprT = in_sides:read(8)
  local lwrT = in_sides:read(8)
  local midT = in_sides:read(8)
  if textures[uprT] then
    textures[uprT]=textures[uprT]+1
  else
    textures[uprT]=1
  end
  if textures[lwrT] then
    textures[lwrT]=textures[lwrT]+1
  else
    textures[lwrT]=1
  end
  if textures[midT] then
    textures[midT]=textures[midT]+1
  else
    textures[midT]=1
  end
  local sec  = string.unpack('H',in_sides:read(2))
  sides[i] = {xoff = xoff, yoff = yoff,uprT = uprT,lwrT = lwrT, midT = midT, sec=sec}
end
--for i,si in ipairs(sides) do
--  print('sidedef ' .. i .. ' uprT:' .. si.uprT .. ' lwrT:' .. si.lwrT .. ' midT:' .. si.midT .. ' sec: ' .. (1+si.sec))
--end
sorted_textures = getKeysSortedByValue(textures, function(a, b) return a > b end)
num_textures = 0
texture_ids = {}
for _,t in ipairs(sorted_textures) do
  local n = textures[t]
  if t:sub(1,1) ~= '-' then
    num_textures   = num_textures + 1
    texture_ids[t] = num_textures
    -- print('texture ' .. t .. ' used ' .. n .. ' time(s) id=' .. texture_ids[t])
  end
end

-- -------------------------------------
-- read sectors
sectors = {}
local in_sectors = assert(io.open(findfile('SECTORS'), 'rb'))
local sz = fsize(in_sectors)
print('sectors file is ' .. sz .. ' bytes')
for i = 1,sz/26 do
  local floor    = string.unpack('h',in_sectors:read(2))
  local ceiling  = string.unpack('h',in_sectors:read(2))
  local floorT   = in_sectors:read(8)
  local ceilingT = in_sectors:read(8)
  local light    = string.unpack('H',in_sectors:read(2))
  local special  = string.unpack('H',in_sectors:read(2))
  local tag      = string.unpack('H',in_sectors:read(2))
  sectors[i] = { floor=floor, ceiling=ceiling, floorT=floorT, ceilingT=ceilingT, light=light, special=special, tag=tag}
end
--for i,s in ipairs(sectors) do
--  print('sector ' .. i)
--  for k,v in pairs(s) do
--    print('   ' .. k .. ' = ' .. v)
--  end
--end

-- -------------------------------------
-- read linedefs
lines = {}
local in_lines = assert(io.open(findfile('LINEDEFS'), 'rb'))
local sz = fsize(in_lines)
print('linedefs file is ' .. sz .. ' bytes')
for i = 1,sz/14 do
  local v0    = string.unpack('H',in_lines:read(2))
  local v1    = string.unpack('H',in_lines:read(2))
  local flags = string.unpack('H',in_lines:read(2))
  local types = string.unpack('H',in_lines:read(2))
  local tag   = string.unpack('H',in_lines:read(2))
  local right = string.unpack('H',in_lines:read(2)) -- sidedef
  local left  = string.unpack('H',in_lines:read(2)) -- sidedef
  lines[i] = {v0 = v0, v1 = v1,flags = flags,types = types, tag = tag,right =right, left = left}
end
--for _,ld in ipairs(lines) do
--  print('right:' .. ld.right .. ' left:' .. ld.left)
--end

-- -------------------------------------
-- read segs
segs = {}
local in_segs = assert(io.open(findfile('SEGS'), 'rb'))
local sz = fsize(in_segs)
local maxseglen = 0.0
print('segs file is ' .. sz .. ' bytes')
for i = 1,sz/12 do
  local v0  = string.unpack('H',in_segs:read(2))
  local v1  = string.unpack('H',in_segs:read(2))
  local agl = string.unpack('h',in_segs:read(2))
  local ldf = string.unpack('H',in_segs:read(2))
  local dir = string.unpack('h',in_segs:read(2))
  local off = string.unpack('h',in_segs:read(2))
  dx = verts[1+v1].x-verts[1+v0].x
  dy = verts[1+v1].y-verts[1+v0].y 
  seglen = math.sqrt(dx*dx+dy*dy)
  segs[i] = {v0=v0,v1=v1,agl=agl,ldf=ldf,dir=dir,off=off,seglen=seglen}
  if (seglen > maxseglen) then
    maxseglen = seglen
  end
end
print('max seg len is ' .. maxseglen .. ' units.')
--for _,s in ipairs(segs) do
--  print('v0 = ' .. s.v0 .. ', v1 = ' .. s.v1)
--  print('agl = ' .. s.agl .. ', linedef = ' .. s.ldf)
--  print('dir = ' .. s.dir .. ', off = ' .. s.off)
--end

-- -------------------------------------
-- read ssectors
ssectors = {}
local in_ssectors = assert(io.open(findfile('SSECTORS'), 'rb'))
local sz = fsize(in_ssectors)
print('ssectors file is ' .. sz .. ' bytes')
for i = 1,sz/4 do
  local num_segs  = string.unpack('H',in_ssectors:read(2))
  local start_seg = string.unpack('H',in_ssectors:read(2))
  ssectors[i] = {num_segs=num_segs,start_seg=start_seg}
end
--for _,ss in ipairs(ssectors) do
--  print('num_segs = ' .. ss.num_segs .. ', start_seg = ' .. ss.start_seg)
--end

-- -------------------------------------
-- read nodes
nodes = {}
local in_nodes = assert(io.open(findfile('NODES'), 'rb'))
local sz = fsize(in_nodes)
print('nodes file is ' .. sz .. ' bytes')
root = sz//28-1
for i = 1,sz/28 do
  local x  = string.unpack('h',in_nodes:read(2)) 
  local y  = string.unpack('h',in_nodes:read(2)) 
  local dx = string.unpack('h',in_nodes:read(2)) 
  local dy = string.unpack('h',in_nodes:read(2)) 
  local rby_up = string.unpack('h',in_nodes:read(2)) 
  local rby_dw = string.unpack('h',in_nodes:read(2)) 
  local rbx_dw = string.unpack('h',in_nodes:read(2)) 
  local rbx_up = string.unpack('h',in_nodes:read(2)) 
  local lby_up = string.unpack('h',in_nodes:read(2)) 
  local lby_dw = string.unpack('h',in_nodes:read(2)) 
  local lbx_dw = string.unpack('h',in_nodes:read(2)) 
  local lbx_up = string.unpack('h',in_nodes:read(2))
  local rchild = string.unpack('H',in_nodes:read(2))
  local lchild = string.unpack('H',in_nodes:read(2))
  nodes[i] = {x=x,y=y,dx=dx,dy=dy,
         rby_up=rby_up,rby_dw=rby_dw,rbx_dw=rbx_dw,rbx_up=rbx_up,
         lby_up=lby_up,lby_dw=lby_dw,lbx_dw=lbx_dw,lbx_up=lbx_up,
         rchild=rchild,lchild=lchild}
end
--for _,n in ipairs(nodes) do
--  print('x = ' .. n.x .. ', y = ' .. n.y)
--  print('dx = ' .. n.dx .. ', dy = ' .. n.dy)
--  print('rchild = ' .. n.rchild .. ', lchild = ' .. n.lchild)
--end

-- -------------------------------------
-- read demo path
demo_path = {}
local in_path = assert(io.open(findfile('TEST.lmp'), 'rb'))
local sz = fsize(in_path)
print('demo file is ' .. sz .. ' bytes')
for i = 1,13 do -- skip header
  local h = string.unpack('B',in_path:read(1))
end
k = 1
for i = 1,(sz-13)/4 do
  local straight = string.unpack('b',in_path:read(1))
  local strafe   = string.unpack('b',in_path:read(1))
  local turn     = string.unpack('b',in_path:read(1))
  local other    = string.unpack('B',in_path:read(1))
  if straight ~= 0 or strafe ~= 0 or turn ~= 0 then
    demo_path[k] = {
      straight=straight, strafe=strafe, turn=turn, other=other
    }
    k = k + 1
  end
end

-- -------------------------------------
-- player start
local in_things = assert(io.open(findfile('THINGS'), 'rb'))
local sz = fsize(in_things)
print('things file is ' .. sz .. ' bytes')
for i = 1,sz/10 do
  local x   = string.unpack('h',in_things:read(2))
  local y   = string.unpack('h',in_things:read(2))
  local a   = string.unpack('h',in_things:read(2))
  local ty  = string.unpack('H',in_things:read(2))
  local opt = string.unpack('H',in_things:read(2))
  if ty == 1 then
    print('Player start at ' .. x .. ',' .. y .. ' angle: ' .. a)
    player_start_x = x
    player_start_y = y
    player_start_a = a*1024//90;
    break;
  end
end

-- -------------------------------------
-- prepare custom data structures
bspNodes    = {}
bspSSectors = {}
bspSegs     = {}
for i,n in ipairs(nodes) do
  bspNodes[i] = {
    x  = n.x,
    y  = n.y,
    dx = n.dx,
    dy = n.dy,
    rchild = n.rchild,
    lchild = n.lchild,
  }
end
for i,ss in ipairs(ssectors) do
  -- identify parent sector
  seg  = segs[1+ss.start_seg]
  ldef = lines[1+seg.ldf]  
  if seg.dir == 0 then
    sidedef = sides[1+ldef.right]
  else
    sidedef = sides[1+ldef.left]
  end
  parent = sectors[1+sidedef.sec]
  -- store
  bspSSectors[i] = {
    num_segs  = ss.num_segs,
    start_seg = ss.start_seg,
    f_h       = parent.floor-40,
    c_h       = parent.ceiling-40,
  }
end
for i,sg in ipairs(segs) do
  ldef = lines[1+sg.ldf]
  other_sidedef = nil
  if sg.dir == 0 then
    sidedef = sides[1+ldef.right]
    if ldef.left < 65535 then
      other_sidedef = sides[1+ldef.left]
    end
  else
    sidedef = sides[1+ldef.left]
    other_sidedef = sides[1+ldef.right]
  end
  lwr = 0
  if sidedef.lwrT:sub(1, 1) ~= '-' then
    lwr = texture_ids[sidedef.lwrT]
  end
  upr = 0
  if sidedef.uprT:sub(1, 1) ~= '-' then
    upr = texture_ids[sidedef.uprT]
  end
  mid = 0
  if sidedef.midT:sub(1, 1) ~= '-' then
    mid = texture_ids[sidedef.midT]
  end
  other_f_h = 0
  other_c_h = 0
  if other_sidedef then
    other_f_h = sectors[1+other_sidedef.sec].floor-40
    other_c_h = sectors[1+other_sidedef.sec].ceiling-40
  end
  -- print('textures ids ' .. lwr .. ',' .. mid .. ',' .. upr)
  bspSegs[i] = {
    v0x       = verts[1+sg.v0].x,
    v0y       = verts[1+sg.v0].y,
    v1x       = verts[1+sg.v1].x,
    v1y       = verts[1+sg.v1].y,
    upr       = upr,
    lwr       = lwr,
    mid       = mid,
    other_f_h = other_f_h,
    other_c_h = other_c_h,
    off       = sg.off,
    seglen    = sg.seglen
  }
end

-- -------------------------------------
-- utility functions to pack records
function pack_bsp_node_coords(node)
  local bin = 0
  bin = '64h' 
        .. string.format("%04x",node.dy ):sub(-4)
        .. string.format("%04x",node.dx ):sub(-4)
        .. string.format("%04x",node.y  ):sub(-4)
        .. string.format("%04x",node.x  ):sub(-4)
  return bin
end

function pack_bsp_node_children(node)
  local bin = 0
  bin = '32h' 
        .. string.format("%04x",node.lchild ):sub(-4)
        .. string.format("%04x",node.rchild ):sub(-4)
  return bin
end

function pack_bsp_ssec(ssec)
  local bin = 0
  bin = '56h' 
        .. string.format("%04x",ssec.c_h):sub(-4)
        .. string.format("%04x",ssec.f_h):sub(-4)
        .. string.format("%04x",ssec.start_seg):sub(-4)
        .. string.format("%02x",ssec.num_segs ):sub(-2)
  return bin
end

function pack_bsp_seg_coords(seg)
  local bin = 0
  bin = '64h' 
        .. string.format("%04x",seg.v1y):sub(-4)
        .. string.format("%04x",seg.v1x):sub(-4)
        .. string.format("%04x",seg.v0y):sub(-4)
        .. string.format("%04x",seg.v0x):sub(-4)
  return bin
end

function pack_bsp_seg_tex_height(seg)
  local bin = 0
  bin = '56h' 
        .. string.format("%02x",seg.upr):sub(-2)
        .. string.format("%02x",seg.mid):sub(-2)
        .. string.format("%02x",seg.lwr):sub(-2)
        .. string.format("%04x",seg.other_c_h):sub(-4)
        .. string.format("%04x",seg.other_f_h):sub(-4)
  return bin
end

function pack_bsp_seg_texmapping(seg)
  local bin = 0
  bin = '32h' 
        .. string.format("%04x",math.floor(0.5+seg.off)):sub(-4)
        .. string.format("%04x",math.floor(0.5+seg.seglen)):sub(-4)
  return bin
end

function pack_demo_path(p)
  local bin = 0
  bin = '24h'
        .. string.format("%02x",p.straight):sub(-2)
        .. string.format("%02x",p.strafe):sub(-2)
        .. string.format("%02x",p.turn):sub(-2)
  return bin
end

-- -------------------------------------
-- report
print('- ' .. #ssectors .. ' sub-sectors')
print('- ' .. #nodes .. ' nodes')
print('- ' .. #segs .. ' segs')
print('- ' .. (num_textures-1) .. ' textures')
-- error('stop')

-- -------------------------------------
