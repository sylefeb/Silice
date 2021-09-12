-- include ASM code as a BROM
-- MIT license, see LICENSE_MIT in Silice repo root

if not path then
  path,_1,_2 = string.match(findfile('pre_tga2c.lua'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
  print('PATH is ' .. path)
end

local fnt = get_image_as_table(path .. 'tests/c/fonts/FCUBEF2.tga')

local out = assert(io.open(path .. 'tests/c/fonts/FCUBEF2.h', "w"))
out:write('unsigned char font_FCUBEF2[]={')
for j=1,#fnt do
  for i=1,#fnt[1] do
    local v = fnt[j][i];
    if v > 0 and v < 255 then v = v * 20 end
    if v == 255 then v = 0 end
    out:write(v .. ',')
  end
  out:write('\n')
end
out:write('0};\n')
out:write('int font_FCUBEF2_width[]={')
local content='abcdefghijlmnopqrstuvwxyz1234567890.,:!?k'
local lttrsz ={11,11,10,11,11,10,13,12,4,12,11,16,11,11,11,11,9,11,11,11,11,16,11,11,11,8,11,12,11,11,12,11,11,11,11,4,4,4,4,9,12}
for i=0,255 do
  local idx = string.find(content,string.char(i), 1, true)
  if idx then 
    out:write(lttrsz[idx] .. ',')
  else      
    out:write(0 .. ',')
  end
end
out:write(0 .. '};\n')

out:write('int font_FCUBEF2_ascii[]={')
for i=0,255 do
  local idx = string.find(content,string.char(i), 1, true)
  if idx then 
    print('found ' .. string.char(i) .. ' at ' .. idx) 
    local start = 0
    for l=1,idx-1 do
      start = start + lttrsz[l]
    end
    print('starts at pixel ' .. start)
    out:write(start .. ',')
  else
    out:write(-1 .. ',')
  end
end 
out:write(-1 .. '};\n')
out:write('int font_FCUBEF2_height=15;\n')
out:close()
