-- SL 2020-04-30

SINGLE_TEXTURE = 0

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

-- -----------------------------------
-- locate a pos in the BSP (returns sub-sector)
function bspLocate(posx,posy)
  queue     = {}
  queue_ptr = 1
  queue[queue_ptr] = root
  queue_ptr = queue_ptr + 1
  while queue_ptr > 1 do
    n = queue[queue_ptr-1]
    queue_ptr = queue_ptr - 1
    if (n&(1<<15)) == 0 then
      lx  = bspNodes[1+n].x
      ly  = bspNodes[1+n].y
      ldx = bspNodes[1+n].dx
      ldy = bspNodes[1+n].dy
      r   = bspNodes[1+n].rchild
      l   = bspNodes[1+n].lchild
      -- which side are we on?
      dx     = posx - lx
      dy     = posy - ly
      csl    = dx * ldy
      csr    = dy * ldx
      if csr > csl then
        -- front
        queue[queue_ptr] = bspNodes[1+n].rchild;
        queue_ptr = queue_ptr + 1     
        queue[queue_ptr] = bspNodes[1+n].lchild;
        queue_ptr = queue_ptr + 1     
      else
        -- back
        queue[queue_ptr] = bspNodes[1+n].lchild;
        queue_ptr = queue_ptr + 1     
        queue[queue_ptr] = bspNodes[1+n].rchild;
        queue_ptr = queue_ptr + 1     
      end
    else
      ssid = (n&(~(1<<15)))
      ss   = ssectors[1+ssid]
      seg  = segs[1+ss.start_seg]
      ldef = lines[1+seg.ldf]  
      if seg.dir == 0 then
        sidedef = sides[1+ldef.right]
      else
        sidedef = sides[1+ldef.left]
      end
      return ssid,sidedef.sec   
    end
  end
end

-- -------------------------------------
-- rounding
function round(x)
  return math.floor(x+0.5)
end

-- -------------------------------------
-- read vertices
verts = {}
local in_verts = assert(io.open(findfile('lumps/VERTEXES.lump'), 'rb'))
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
local in_sides = assert(io.open(findfile('lumps/SIDEDEFS.lump'), 'rb'))
local sz = fsize(in_sides)
print('sidedefs file is ' .. sz .. ' bytes')
for i = 1,sz/30 do
  local xoff = string.unpack('h',in_sides:read(2))
  local yoff = string.unpack('h',in_sides:read(2))
  local uprT = in_sides:read(8):match("[%_-%a%d]+")
  local lwrT = in_sides:read(8):match("[%_-%a%d]+")
  local midT = in_sides:read(8):match("[%_-%a%d]+")
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

-- -------------------------------------
-- read sectors
sectors = {}
local in_sectors = assert(io.open(findfile('lumps/SECTORS.lump'), 'rb'))
local sz = fsize(in_sectors)
print('sectors file is ' .. sz .. ' bytes')
for i = 1,sz/26 do
  local floor    = string.unpack('h',in_sectors:read(2))
  local ceiling  = string.unpack('h',in_sectors:read(2))
  local floorT   = in_sectors:read(8):match("[%_-%a%d]+")
  local ceilingT = in_sectors:read(8):match("[%_-%a%d]+")  
  local light    = string.unpack('H',in_sectors:read(2))
  local special  = string.unpack('H',in_sectors:read(2))
  local tag      = string.unpack('H',in_sectors:read(2))
  if textures[floorT] then
    textures[floorT]=textures[floorT]+1
  else
    textures[floorT]=1
  end
  if textures[ceilingT] then
    textures[ceilingT]=textures[ceilingT]+1
  else
    textures[ceilingT]=1
  end
  sectors[i] = { floor=floor, ceiling=ceiling, floorT=floorT, ceilingT=ceilingT, light=light, special=special, tag=tag}
end
--for i,s in ipairs(sectors) do
--  print('sector ' .. i)
--  for k,v in pairs(s) do
--    print('   ' .. k .. ' = ' .. v)
--  end
--end

-- -------------------------------------
-- sort textures by usage
sorted_textures = getKeysSortedByValue(textures, function(a, b) return a > b end)
num_textures = 0
texture_ids = {} -- valid ids start at 1
for _,t in ipairs(sorted_textures) do
  local n = textures[t]
  if t:sub(1,1) ~= '-' then
    num_textures   = num_textures + 1
    texture_ids[t] = num_textures
    print('texture ' .. t .. ' used ' .. n .. ' time(s) id=' .. texture_ids[t])
  end
end

if SINGLE_TEXTURE == 1 then
  local singletex    = sorted_textures[2] -- [1] is '-'
  texture_ids = {}
  texture_ids[singletex] = 1
  textures[singletex] = 1
  for _,s in pairs(sectors) do
    s.floorT   = singletex
    if s.ceilingT ~= 'F_SKY1' then
      s.ceilingT = singletex
    end
  end
  for _,s in pairs(sides) do
    if s.uprT:sub(1, 1) ~= '-' and s.uprT ~= 'F_SKY1' then
      s.uprT = singletex
    end
    if s.lwrT:sub(1, 1) ~= '-' and s.lwrT ~= 'F_SKY1' then
      s.lwrT = singletex
    end
    if s.midT:sub(1, 1) ~= '-' and s.midT ~= 'F_SKY1' then
      s.midT = singletex
    end
  end
end

-- -------------------------------------
-- read linedefs
lines = {}
local in_lines = assert(io.open(findfile('lumps/LINEDEFS.lump'), 'rb'))
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
local in_segs = assert(io.open(findfile('lumps/SEGS.lump'), 'rb'))
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
if (maxseglen*maxseglen / 32) > 65535 then
  error('squared segment length too large for 16 bits')
end
--for _,s in ipairs(segs) do
--  print('v0 = ' .. s.v0 .. ', v1 = ' .. s.v1)
--  print('agl = ' .. s.agl .. ', linedef = ' .. s.ldf)
--  print('dir = ' .. s.dir .. ', off = ' .. s.off)
--end

-- -------------------------------------
-- read ssectors
ssectors = {}
local in_ssectors = assert(io.open(findfile('lumps/SSECTORS.lump'), 'rb'))
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
local in_nodes = assert(io.open(findfile('lumps/NODES.lump'), 'rb'))
local sz = fsize(in_nodes)
print('nodes file is ' .. sz .. ' bytes')
root = sz//28-1
for i = 1,sz/28 do
  local x  = string.unpack('h',in_nodes:read(2)) 
  local y  = string.unpack('h',in_nodes:read(2)) 
  local dx = string.unpack('h',in_nodes:read(2)) 
  local dy = string.unpack('h',in_nodes:read(2)) 
  local rby_hi = string.unpack('h',in_nodes:read(2)) 
  local rby_lw = string.unpack('h',in_nodes:read(2)) 
  local rbx_lw = string.unpack('h',in_nodes:read(2)) 
  local rbx_hi = string.unpack('h',in_nodes:read(2)) 
  local lby_hi = string.unpack('h',in_nodes:read(2)) 
  local lby_lw = string.unpack('h',in_nodes:read(2)) 
  local lbx_lw = string.unpack('h',in_nodes:read(2)) 
  local lbx_hi = string.unpack('h',in_nodes:read(2))
  local rchild = string.unpack('H',in_nodes:read(2))
  local lchild = string.unpack('H',in_nodes:read(2))
  nodes[i] = {x=x,y=y,dx=dx,dy=dy,
         rby_hi=rby_hi,rby_lw=rby_lw,rbx_lw=rbx_lw,rbx_hi=rbx_hi,
         lby_hi=lby_hi,lby_lw=lby_lw,lbx_lw=lbx_lw,lbx_hi=lbx_hi,
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
if SIMULATION then
in_path = io.open(findfile('poslog_debug.txt'), 'r')
else
in_path = io.open(findfile('poslog_final.txt'), 'r')
end
k = 1
prev_x = -1
prev_y = -1
prev_z = -1
prev_a = -1
for line in in_path:lines() do
  local angle, x, y, z = line:match("(%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+)")
  if angle then
    if k > 1 then
      mid_x = round((prev_x + x)/2)
      mid_y = round((prev_y + y)/2)
      mid_z = round((prev_z + z)/2)
      if math.abs(angle - prev_a) < 512 then
        mid_a = round((prev_a + angle)/2)
      else
        mid_a = angle
      end
    --  demo_path[k] = {
    --    x=mid_x, y=mid_y, z=mid_z, angle=mid_a
    --  }
    --  k = k + 1
    end
    prev_x = x
    prev_y = y
    prev_z = z
    prev_a = angle
    demo_path[k] = {
      x=x, y=y, z=z, angle=angle
    }
    k = k + 1
  end
end
if k == 1 then
  error('empty demo path!')
end

-- -------------------------------------
-- find all sector doors
doors = {}
id    = 1
for _,ldef in pairs(lines) do
  if ldef.types == 1 then
    sidedef   = sides[1+ldef.left]
    doorsec   = sidedef.sec
    print('sector ' .. doorsec .. ' is a door')
    othersidedef = sides[1+ldef.right]
    print('       opens until ' .. sectors[1+othersidedef.sec].ceiling)
    if not doors[doorsec] then
      doors[doorsec] = { 
        id     = id,
        openh  = sectors[1+othersidedef.sec].ceiling,
        closeh = sectors[1+othersidedef.sec].floor
        }
      id = id + 1
    else
      doors[doorsec].openh  = round(math.min(doors[doorsec].openh,  sectors[1+othersidedef.sec].ceiling))
      doors[doorsec].closeh = round(math.max(doors[doorsec].closeh, sectors[1+othersidedef.sec].floor))
    end
  end
end
-- open all doors!
--for sec,door in pairs(doors) do
--  sectors[1+sec].ceiling = door.openh
--end

-- -------------------------------------
-- find min light level of neighboring sectors
lowlights = {}
for _,ldef in pairs(lines) do
  sidedef      = sides[1+ldef.right]
  sec          = sidedef.sec
  if ldef.left < 65535 then
    othersidedef = sides[1+ldef.left]
    osec = othersidedef.sec;
    if not lowlights[sec] then
      lowlights[sec] = { level = sectors[1+osec].light }
    else
      lowlights[sec].level = math.min(lowlights[sec].level,sectors[1+osec].light)
    end
    if not lowlights[osec] then
      lowlights[osec] = { level = sectors[1+sec].light }
    else
      lowlights[osec].level = math.min(lowlights[osec].level,sectors[1+sec].light)
    end
  end
end
for s,l in pairs(lowlights) do
  print('sector ' .. s .. ' light: ' .. sectors[1+s].light .. ' lowlight: ' .. l.level)
end

-- -------------------------------------
-- prepare custom data structures
bspNodes    = {}
bspSSectors = {}
bspSegs     = {}
bspDoors    = {}
maxdoorid   = 0
for sec,d in pairs(doors) do
  bspDoors[d.id] = {
    h      = d.openh,
    openh  = d.openh,
    closeh = d.closeh
  }
  maxdoorid = math.max(maxdoorid,d.id)
end
print('' .. maxdoorid .. ' doors in level')

for i,n in ipairs(nodes) do
  bspNodes[i] = {
    x  = n.x,
    y  = n.y,
    dx = n.dx,
    dy = n.dy,
    rchild = n.rchild,
    lchild = n.lchild,
    lbx_hi = n.lbx_hi,
    lbx_lw = n.lbx_lw,
    lby_hi = n.lby_hi,
    lby_lw = n.lby_lw,
    rbx_hi = n.rbx_hi,
    rbx_lw = n.rbx_lw,
    rby_hi = n.rby_hi,
    rby_lw = n.rby_lw,
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
  --- door?
  doorid = 0
  if doors[sidedef.sec] then
    doorid = doors[sidedef.sec].id
  end
  -- textures
  f_T   = texture_ids[parent.floorT]
  if parent.ceilingT == 'F_SKY1' then
    c_T = 0
  else
    c_T = texture_ids[parent.ceilingT]
  end
  lowlight = 0
  if lowlights[sidedef.sec] then
    lowlight = lowlights[sidedef.sec].level
  end
  seclight = parent.light
--  if lowlight >= seclight 
--  and (parent.special == 2 or parent.special == 3 or parent.special == 4) then
--    print('sector ' .. sidedef.sec .. ' forcing light to zero (seclight: ' .. seclight .. ' lowlight:' .. lowlight .. ')')
--    seclight = 0
--  end
  -- store
  bspSSectors[i] = {
    sec       = sidedef.sec,
    num_segs  = ss.num_segs,
    start_seg = ss.start_seg,
    f_h       = parent.floor,
    c_h       = parent.ceiling,
    f_T       = f_T,
    c_T       = c_T,
    light     = round(math.min(31,(255 - seclight)/8)),
    lowlight  = round(math.min(31,(255 - lowlight)/8)),
    special   = parent.special,
    doorid    = doorid
  }
  --print('sector ' .. sidedef.sec .. ' seclight: ' .. seclight .. ' lowlight:' .. lowlight)
  --print('  ' .. i-1 .. ' ' .. ' seclight: ' .. bspSSectors[i].light .. ' lowlight:' .. bspSSectors[i].lowlight)
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
  -- textures
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
  -- adjust for sky
  if other_sidedef then
    if     sectors[1+sidedef.sec].ceilingT == 'F_SKY1'
       and sectors[1+other_sidedef.sec].ceilingT == 'F_SKY1' then
      upr = 0 -- texture_ids['F_SKY1']
    end
  end
  -- other sector floor/ceiling heights
  other_f_h = 0
  other_c_h = 0
  other_doorid = 0
  if other_sidedef then
    other_f_h    = sectors[1+other_sidedef.sec].floor
    other_c_h    = sectors[1+other_sidedef.sec].ceiling
    doorid       = 0
    if doors[other_sidedef.sec] then
      doorid     = doors[other_sidedef.sec].id
    end
    other_doorid = doorid
  end
  -- print('textures ids ' .. lwr .. ',' .. mid .. ',' .. upr)
  local xoff = sidedef.xoff + sg.off
  --[[if (sg.dir == 1) then
    -- correct texture offset NOTE: TODO not yet checked, does this work?
    local dx      = verts[ldef.v1].x - verts[ldef.v0].x
    local dy      = verts[ldef.v1].y - verts[ldef.v0].y
    local ldeflen = math.sqrt(dx*dx+dy*dy)
    local xoff    = round(sidedef.xoff + (ldeflen - sg.off))
  end]]
  if (sg.dir == 1) then
    -- revert to be oriented as linedef
    v1x       = verts[1+sg.v0].x
    v1y       = verts[1+sg.v0].y
    v0x       = verts[1+sg.v1].x
    v0y       = verts[1+sg.v1].y
  else
    v0x       = verts[1+sg.v0].x
    v0y       = verts[1+sg.v0].y
    v1x       = verts[1+sg.v1].x
    v1y       = verts[1+sg.v1].y  
  end
  lower_unpegged = 0
  if (ldef.flags & 16) ~= 0 then
    lower_unpegged = 1
  end
  upper_unpegged = 0
  if (ldef.flags & 8) ~= 0 then
    upper_unpegged = 1
  end
  bspSegs[i] = {
    v0x       = v0x,
    v0y       = v0y,
    v1x       = v1x,
    v1y       = v1y,
    upr       = upr,
    lwr       = lwr,
    mid       = mid,
    other_f_h = other_f_h,
    other_c_h = other_c_h,
    other_doorid = other_doorid,
    xoff      = xoff,
    yoff      = sidedef.yoff,
    seglen    = sg.seglen,
    segsqlen  = math.ceil(sg.seglen*sg.seglen/32),
    lower_unpegged = lower_unpegged,
    upper_unpegged = upper_unpegged
  }
end

-- -------------------------------------
-- things (player start, monsters)
local in_things = assert(io.open(findfile('lumps/THINGS.lump'), 'rb'))
local sz = fsize(in_things)
print('things file is ' .. sz .. ' bytes')
nthings = 0
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
  elseif ty == 3004 then -- POSS
    print('POSS at ' .. x .. ',' .. y .. ' angle: ' .. a)
    print(' --> sector ' .. bspLocate(x,y))
  end
  nthings = nthings + 1
end
print('level contains ' .. nthings .. ' things')

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

function pack_bsp_node_children_box(node)
  local bin = 0
  bin = '128h' 
        .. string.format("%04x",node.lby_hi):sub(-4)
        .. string.format("%04x",node.lby_lw):sub(-4)
        .. string.format("%04x",node.lbx_hi):sub(-4)
        .. string.format("%04x",node.lbx_lw):sub(-4)
        .. string.format("%04x",node.rby_hi):sub(-4)
        .. string.format("%04x",node.rby_lw):sub(-4)
        .. string.format("%04x",node.rbx_hi):sub(-4)
        .. string.format("%04x",node.rbx_lw):sub(-4)
  return bin
end

function pack_bsp_ssec(ssec)
  local bin = 0
  bin = '64h' 
        .. string.format("%02x",ssec.doorid):sub(-2)
        .. string.format("%04x",ssec.c_h):sub(-4)
        .. string.format("%04x",ssec.f_h):sub(-4)
        .. string.format("%04x",ssec.start_seg):sub(-4)
        .. string.format("%02x",ssec.num_segs ):sub(-2)
  return bin
end

function pack_bsp_ssec_flats(ssec)
  local bin = 0
  bin = '40h'
        .. string.format("%02x",ssec.lowlight):sub(-2)
        .. string.format("%02x",math.min(255,ssec.special)):sub(-2)
        .. string.format("%02x",ssec.light):sub(-2)
        .. string.format("%02x",ssec.c_T  ):sub(-2)
        .. string.format("%02x",ssec.f_T  ):sub(-2)
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
  bin = '64h' 
        .. string.format("%02x",seg.other_doorid):sub(-2)
        .. string.format("%02x",seg.upr):sub(-2)
        .. string.format("%02x",seg.mid):sub(-2)
        .. string.format("%02x",seg.lwr):sub(-2)
        .. string.format("%04x",seg.other_c_h):sub(-4)
        .. string.format("%04x",seg.other_f_h):sub(-4)
  return bin
end

function pack_bsp_seg_texmapping(seg)
  local bin = 0
  bin = '66h'
        .. ((seg.upper_unpegged<<1) | seg.lower_unpegged)
        .. string.format("%04x",round(seg.segsqlen)):sub(-4)
        .. string.format("%04x",round(seg.yoff)):sub(-4)
        .. string.format("%04x",round(seg.xoff)):sub(-4)
        .. string.format("%04x",round(seg.seglen)):sub(-4)
  return bin
end

function pack_demo_path(p)
  local bin = 0
  bin = '64h'
        .. string.format("%04x",p.angle):sub(-4)
        .. string.format("%04x",p.z):sub(-4)
        .. string.format("%04x",p.y):sub(-4)
        .. string.format("%04x",p.x):sub(-4)
  return bin
end

function pack_door(d)
  local bin = 0
  bin = '49h1' -- msb indicate door direction
        .. string.format("%04x",d.closeh):sub(-4)
        .. string.format("%04x",d.openh):sub(-4)
        .. string.format("%04x",d.h):sub(-4)
  return bin
end

-- -------------------------------------
-- report
print('- ' .. #ssectors .. ' sub-sectors')
print('- ' .. #nodes .. ' nodes')
print('- ' .. #segs .. ' segs')
print('- ' .. (num_textures-1) .. ' textures')

-- -------------------------------------
