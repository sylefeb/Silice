-- pack terrain data in a raw binary image

width  = 320
height = 240

if not path then
  path,_1,_2 = string.match(findfile('Makefile'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
  print('********************* data written to  ' .. path .. '/data.raw')
  print('********************* images read from ' .. path .. '/data/*.tga')
end

if not terrain then
  terrain = ''
end

local out = assert(io.open(path .. '/data.raw', "wb"))
offset = 0
print('terrain starts at ' .. offset)
-- store terrain data
t=1
colormap  = get_image_as_table  (path .. '/data/color' .. t .. '.tga')
palette   = get_palette_as_table(path .. '/data/color' .. t .. '.tga')
heightmap = get_image_as_table  (path .. '/data/height' .. t .. '.tga')
local w = #colormap[1]
local h = #colormap
if w ~= #heightmap[1] then error('size mismatch between maps') end
if h ~= #heightmap    then error('size mismatch between maps') end
print('color + height data is ' .. w .. 'x' .. h .. 'x24 bits, ' .. w*h*4 .. ' bytes')
for j = 1,h do
  for i = 1,w do
    local clr  = 1 + colormap [j][i]
    -- TODO: lookup RGB and encode as 565
    local r       =  palette[clr]     &255
    local g       = (palette[clr]>> 8)&255
    local b       = (palette[clr]>>16)&255
    local rgb_565 = ((b >> 3) << 11) | ((g >> 2) << 5) | (r >> 3)
    local hgt     = heightmap[j][i]
    out:write(string.pack('B', hgt ))
    out:write(string.pack('B', rgb_565&255  ))
    out:write(string.pack('B', rgb_565>>8 ))
    out:write(string.pack('B', 0   )) -- padding to have a x4 multiplier
  end
end
offset = offset + w*h*4
-- pad with zeros to reach a power of 2 offset larger the terrain data
while offset < (1<<22) do
  out:write(string.pack('B', 0 ))
  offset = offset + 1
end
-- store pre-computed table for all steps
print('steps table starts at ' .. offset)
-- table is width x 256 x 64bits
--  for all x_step,z_step stores
--  inverse z  (16 bits, 2 bytes)
--  x offset   (24 bits, 3 bytes)
--  0 padding  (3 bytes)
fp     = 11
fp_scl = 1<<fp
z_step = fp_scl
ratio  = (1.3334*height)//width
one_over_width = fp_scl//width
for x=0,width-1 do
  z      = z_step
  for iz=0,255 do
    inv_z = (fp_scl*fp_scl) // z;
    -- print('z = ' .. z .. ' inv_z = ' .. inv_z)
    x_off  = - math.floor(z/ratio) + ((x * math.ceil(2*z/ratio) * one_over_width) >> fp)
    if (x_off < -(1<<23)+1) or (x_off > (1<<23)) then
      error('x_off too large')
    end
    -- print('x_off = ' .. x_off)
    z     = z + z_step
    out:write(string.pack('B', (inv_z>> 8)&255 ))
    out:write(string.pack('B',  inv_z     &255 ))
    out:write(string.pack('B', (x_off>>16)&255 ))
    out:write(string.pack('B', (x_off>> 8)&255 ))
    out:write(string.pack('B',  x_off     &255 ))
    out:write(string.pack('B',  0              ))
    out:write(string.pack('B',  0              ))
    out:write(string.pack('B',  0              ))
    offset = offset + 8
  end
end
print('before padding: ' .. offset .. ' bytes')
-- pad with zeros to reach 2^22+2^20
while offset < (1<<22)+(1<<20) do
  out:write(string.pack('B', 0 ))
  offset = offset + 1
end

-- configuration commands
config = (width<<16)|(height-1);
out:write(string.pack('B',0xC0))
out:write(string.pack('B',(config>>24)&255))
out:write(string.pack('B',0xC0))
out:write(string.pack('B',(config>>16)&255))
out:write(string.pack('B',0xC0))
out:write(string.pack('B',(config>> 8)&255))
out:write(string.pack('B',0xC0))
out:write(string.pack('B',(config    )&255))
offset = offset + 8
-- screen init commands
-- reset
for i=1,16 do
  out:write(string.pack('B',0x82))
  out:write(string.pack('B',0x00))
  offset = offset + 2
end
-- exit reset
for i=1,16 do
  out:write(string.pack('B',0x80))
  out:write(string.pack('B',0x00))
  offset = offset + 2
end
-- send init commands
out:write(string.pack('B',0x01))
out:write(string.pack('B',0x01))
offset = offset + 2
out:write(string.pack('B',0x01))
out:write(string.pack('B',0x11))
offset = offset + 2
out:write(string.pack('B',0x01))
out:write(string.pack('B',0x3A))
offset = offset + 2
out:write(string.pack('B',0x00))
out:write(string.pack('B',0x55))
offset = offset + 2
out:write(string.pack('B',0x01))
out:write(string.pack('B',0x36))
offset = offset + 2
out:write(string.pack('B',0x00))
out:write(string.pack('B',0xC0))
offset = offset + 2
out:write(string.pack('B',0x01))
out:write(string.pack('B',0x21))
offset = offset + 2
out:write(string.pack('B',0x01))
out:write(string.pack('B',0x13))
offset = offset + 2
out:write(string.pack('B',0x01))
out:write(string.pack('B',0x51))
offset = offset + 2
out:write(string.pack('B',0x00))
out:write(string.pack('B',0xFF))
offset = offset + 2
out:write(string.pack('B',0x01))
out:write(string.pack('B',0x29))
offset = offset + 2

-- height
out:write(string.pack('B',0x01))
out:write(string.pack('B',0x2A))
offset = offset + 2
out:write(string.pack('B',0x00))
out:write(string.pack('B',0x00))
offset = offset + 2
out:write(string.pack('B',0x00))
out:write(string.pack('B',0x00))
offset = offset + 2
out:write(string.pack('B',0x00))
out:write(string.pack('B',((height-1)>>8)&255))
offset = offset + 2
out:write(string.pack('B',0x00))
out:write(string.pack('B',((height-1)   )&255))
offset = offset + 2
-- width
out:write(string.pack('B',0x01))
out:write(string.pack('B',0x2B))
offset = offset + 2
out:write(string.pack('B',0x00))
out:write(string.pack('B',0x00))
offset = offset + 2
out:write(string.pack('B',0x00))
out:write(string.pack('B',0x00))
offset = offset + 2
out:write(string.pack('B',0x00))
out:write(string.pack('B',((width-1)>>8)&255 ))
offset = offset + 2
out:write(string.pack('B',0x00))
out:write(string.pack('B',((width-1)   )&255 ))
offset = offset + 2

-- wait for pixels
out:write(string.pack('B',0x01))
out:write(string.pack('B',0x2C))
offset = offset + 2

-- pad with nops
for i=1,128 do
  out:write(string.pack('B',0x80))
  out:write(string.pack('B',0x00))
  offset = offset + 2
end
--
print('data size: ' .. offset .. ' bytes')
out:close()
