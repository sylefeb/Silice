-- include ASM code as a BROM

if not path then
  path,_1,_2 = string.match(findfile('Makefile'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
  print('********************* data written to  ' .. path .. '/terrains.img')
  print('********************* images read from ' .. path .. '/data/*.tga')
end

data_hex = ''

if not terrain then
  terrain = ''
end   

local out = assert(io.open(path .. '/terrains.img', "wb"))
c_hex = ''
for t=1,num_terrains do

  colormap  = get_image_as_table  (path .. '/data/color' .. t .. '.tga')
  palette   = get_palette_as_table(path .. '/data/color' .. t .. '.tga')
  heightmap = get_image_as_table  (path .. '/data/height' .. t .. '.tga')

  local w = #colormap[1]
  local h = #colormap
  if w ~= #heightmap[1] then error('size mismatch between maps') end
  if h ~= #heightmap    then error('size mismatch between maps') end
  print('color + height data is ' .. w .. 'x' .. h .. 'x16 bits, ' .. w*h*2 .. ' bytes')
  for j = 1,h do
    for i = 1,w do
      local clr = colormap [j][i]
      local hgt = heightmap[j][i]
      out:write(string.pack('B', hgt ))
      out:write(string.pack('B', clr ))
      if t == 1 then
        c_hex = c_hex .. string.format("0x%x,", hgt)
        c_hex = c_hex .. string.format("0x%x,", clr)
      end
    end
  end

  print('sky: ' .. terrain_sky_id[t])
  out:write(string.pack('B', terrain_sky_id[t] ))
  if t == 1 then
    c_hex = c_hex .. string.format("0x%x,",  terrain_sky_id[t])
  end

  for c = 1,256 do
    --print('r = ' .. (palette[c]     &255))
    --print('g = ' .. ((palette[c]>> 8)&255))
    --print('b = ' .. ((palette[c]>>16)&255))
    out:write(string.pack('B',  palette[c]     &255 ))
    out:write(string.pack('B', (palette[c]>> 8)&255 ))
    out:write(string.pack('B', (palette[c]>>16)&255 ))
    if t == 1 then
      c_hex = c_hex .. string.format("0x%x,",   palette[c]     &255)
      c_hex = c_hex .. string.format("0x%x,",  (palette[c]>> 8)&255)
      c_hex = c_hex .. string.format("0x%x,",  (palette[c]>>16)&255)
    end
end

end

out:close()

-- also generates a header with first terrain for inclusion in simulation
local out = assert(io.open(path .. '/terrains.h', "wb"))
out:write('unsigned char terrains[]={')
out:write(c_hex)
out:write('0x00};')
out:close()
