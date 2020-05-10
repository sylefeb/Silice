print('preparing textures')

if SIMULATION then
USE_BRAM = false -- RAM or ROM
SHRINK   = 2 -- 0 is original res, 1 half, 2 a quarter
else
USE_BRAM = false -- RAM or ROM
SHRINK   = 0 -- 0 is original res, 1 half, 2 a quarter
             -- synthesis is much fast at a quarter res, recommanded for testing
end

ALL_IN_ONE = false

-- -------------------------------------
-- helper functions

function texture_dim_pow2(dim)
  local pow2=0
  local tmp = dim
  while tmp > 1 do
    pow2 = pow2 + 1
    tmp  = (tmp>>1)
  end
  return pow2,(dim == (1<<pow2))
end

function shrink_tex(img)
  local w = #img[1]
  local h = #img
  local shi = {}
  for j = 1,h//2 do 
    shi[j] = {}
    for i = 1,w//2 do
      shi[j][i] = img[j*2][i*2]
    end
  end
  return shi
end

function update_palette(img,pal)
  local w = #img[1]
  local h = #img
  for j = 1,h do 
    for i = 1,w do
      local clr  = pal[1+img[j][i]]
      local pidx = inv_palette[clr]
      if not pidx then
        error('color not found')
      end
      img[j][i] = pidx - 1
    end
  end
  return img
end

-- -------------------------------------
-- colormap
local in_clrmap = assert(io.open(findfile('COLORMAP'), 'rb'))
local sz = fsize(in_clrmap)
print('colormap file is ' .. sz .. ' bytes')
colormaps={}
for i=1,32 do
  local map = {}
  for c=1,256 do
    local palidx = string.unpack('B',in_clrmap:read(1))
    map[c] = palidx
  end
  colormaps[i] = map
end

-- -------------------------------------
-- palette

local in_pal = assert(io.open(findfile('PLAYPAL'), 'rb'))
local sz = fsize(in_pal)
print('palette file is ' .. sz .. ' bytes')
palette={}
inv_palette={}
palette_666={}
for c=1,256 do
  local r    = string.unpack('B',in_pal:read(1))
  local g    = string.unpack('B',in_pal:read(1))
  local b    = string.unpack('B',in_pal:read(1))
  local rgb     = r + (g*256) + (b*256*256)
  local rgb_666 = (r>>2) + (g>>2)*64 + (b>>2)*64*64
  palette_666[c] = rgb_666
  palette[c] = rgb
  inv_palette[rgb] = c
end
in_pal:close()

-- -------------------------------------
-- get script path
local path,_1,_2 = string.match(findfile('textures.txt'), "(.-)([^\\/]-%.?([^%.\\/]*))$")

-- -------------------------------------
-- parse texture defs
local in_texdefs = assert(io.open(findfile('textures.txt'), 'r'))
num_tex_defs = 0
current = nil
texpatches = {}
imgcur = nil
imgcur_w = 0
imgcur_h = 0

for line in in_texdefs:lines() do
  local name, w, h = line:match("WallTexture ([%a%d_]+), (%d+), (%d+)")
  if name then
    if texture_ids[name] ~= nil then
      -- start new
      print('texdef "' .. name .. '"')
      print('   width:  ' .. w)
      print('   height: ' .. h)
      num_tex_defs = num_tex_defs + 1
      current = name
      imgcur = {}
      for j=1,h do
        imgcur[j] = {}
        for i=1,w do
          imgcur[j][i] = 0
        end
      end
    else
      current = nil
    end
  elseif current ~= nil then    
    -- closing bracket?
    if line:match("}") then
        -- save previous
      if imgcur ~= nil then
        print('saving ' .. current ..  ' ...')
        save_table_as_image_with_palette(imgcur,palette,path .. 'textures/assembled/' .. current .. '.tga')
        print('         ...done.')
      end
      current = nil
      imgcur  = nil
    else
      -- patch?
      local pname, x, y = line:match("%s*Patch ([%a%d_]+), (%-?%d+), (%-?%d+)")
      if pname then
        print('   patch "' .. pname .. '"')
        print('     x:  ' .. x)
        print('     y:  ' .. y)
        if texpatches[pname] then
          texpatches[pname] = texpatches[pname] + 1
        else
          texpatches[pname] = 1
        end
        print('   loading textures/source/' .. pname .. '.tga')
        local pimg = get_image_as_table(path .. 'textures/source/' .. pname .. '.tga')
        local ppal = get_palette_as_table(path .. 'textures/source/' .. pname .. '.tga')
        pimg = update_palette(pimg,ppal)
        local ph = #pimg
        local pw = #pimg[1]
        print('   patch is ' .. pw .. 'x' .. ph)
        for j=1,ph do
          for i=1,pw do
             if ((j+y) <= #imgcur) and ((i+x) <= #imgcur[1]) and (j+y) > 0 and (i+x) > 0 then
               imgcur[math.floor(j+y)][math.floor(i+x)] = pimg[j][i]
             end
          end
        end
        print('   copied.')
      end
    end  
  end  
end
-- save any last one
if current then
  print('saving...')
  save_table_as_image_with_palette(imgcur,palette,path .. 'textures/assembled/' .. current .. '.tga')
  print('         ...done.')
end 

print('num tex defs used: ' .. num_tex_defs)
--for p,i in pairs(texpatches) do
--  print('patch ' .. p .. ' used ' .. i .. ' times')
--end

print('generating texture chip code')
local code = assert(io.open(path .. 'texturechip.ice', 'w'))
code:write([[algorithm texturechip(
  input  uint8 texid,
  input  uint8 iiu,
  input  uint8 iiv,
  input  uint5 light,
  output uint8 palidx) {
  ]])
-- build bram and texture start address table
code:write('  uint8  u    = 0;\n')
code:write('  uint8  v    = 0;\n')
code:write('  uint8  iu   = 0;\n')
code:write('  uint8  iv   = 0;\n')
code:write('  uint16 lit  = 0;\n')
code:write('  brom   uint8 colormap[] = {\n')
for _,cmap in ipairs(colormaps) do
  for _,cidx in ipairs(cmap) do
    code:write('8h'..string.format("%02x",cidx):sub(-2) .. ',')
  end
end
code:write('};\n')
texture_start_addr = 0
texture_start_addr_table = {}
if ALL_IN_ONE then
  if USE_BRAM then
    code:write('  bram uint8 textures[] = {\n')
  else
    code:write('  brom uint8 textures[] = {\n')
  end
end
for tex,id in pairs(texture_ids) do
  -- load assembled texture
  local texpal  = get_palette_as_table(path .. 'textures/assembled/' .. tex .. '.tga')
  local texdata = get_image_as_table(path .. 'textures/assembled/' .. tex .. '.tga')
  texdata = update_palette(texdata,texpal)
  if SHRINK == 2 then
    texdata = shrink_tex(shrink_tex(texdata))
  elseif SHRINK == 1 then
    texdata = shrink_tex(texdata)
  end  
  local texw = #texdata[1]
  local texh = #texdata
  texture_start_addr_table[tex] = texture_start_addr
  texture_start_addr = texture_start_addr + texw * texh
  -- data
  if not ALL_IN_ONE then
    if USE_BRAM then
      code:write('  bram uint8 texture_' .. tex .. '[] = {\n')
    else
      code:write('  brom uint8 texture_' .. tex .. '[] = {\n')
    end
  end
  for j=1,texh do
    for i=1,texw do
      code:write('8h'..string.format("%02x",texdata[j][i]):sub(-2) .. ',')
    end
  end
  if not ALL_IN_ONE then
    code:write('};\n')
  end
end
if ALL_IN_ONE then
  code:write('};\n')
end

-- addressing
if SHRINK == 2 then
  code:write('  iu = iiu>>2;\n')
  code:write('  iv = iiv>>2;\n')
elseif SHRINK == 1 then
  code:write('  iu = iiu>>1;\n')
  code:write('  iv = iiv>>1;\n')
else
  code:write('  iu = iiu;\n')
  code:write('  iv = iiv;\n')
end
code:write('  switch (texid) {\n')
code:write('    default : { }\n')  
for tex,id in pairs(texture_ids) do
  -- load assembled texture
  local texdata = get_image_as_table(path .. 'textures/assembled/' .. tex .. '.tga')
  if SHRINK == 2 then
    texdata = shrink_tex(shrink_tex(texdata))
  elseif SHRINK == 1 then
    texdata = shrink_tex(texdata)
  end  
  local texw = #texdata[1]
  local texh = #texdata
  local texw_pow2,texw_perfect = texture_dim_pow2(texw)
  local texh_pow2,texh_perfect = texture_dim_pow2(texh)
  code:write('    case ' .. (id) .. ': {\n')
  code:write('       // ' .. tex .. ' ' .. texw .. 'x' .. texh .. '\n')
  if not texw_perfect then
    code:write('     if (iu > ' .. (3*texw) ..') {\n')
    code:write('       u = iu - ' .. (3*texw) .. ';\n')
    code:write('     } else {\n')
    code:write('       if (iu > ' .. (2*texw) ..') {\n')
    code:write('         u = iu - ' .. (2*texw) .. ';\n')
    code:write('       } else {\n')
    code:write('         if (iu > ' .. (texw) ..') {\n')
    code:write('           u = iu - ' .. (texw) .. ';\n')
    code:write('         } else {\n')
    code:write('           u = iu;\n')
    code:write('         }\n')
    code:write('       }\n')
    code:write('     }\n')
  end
  if not texh_perfect then
    code:write('     if (iv > ' .. (3*texh) ..') {\n')
    code:write('       v = iv - ' .. (3*texh) .. ';\n')
    code:write('     } else {\n')
    code:write('       if (iv > ' .. (2*texh) ..') {\n')
    code:write('         v = iv - ' .. (2*texh) .. ';\n')
    code:write('       } else {\n')
    code:write('         if (iv > ' .. (texh) ..') {\n')
    code:write('           v = iv - ' .. (texh) .. ';\n')
    code:write('         } else {\n')
    code:write('           v = iv;\n')
    code:write('         }\n')
    code:write('       }\n')
    code:write('     }\n')
  end
  if ALL_IN_ONE then
    code:write('       textures.addr = ' .. texture_start_addr_table[tex] .. ' + ')
  else
    code:write('       texture_' .. tex .. '.addr = ')
  end
  if texw_perfect then
    code:write(' (iu&' .. (texw-1) .. ')')
  else
    code:write(' (u)')
  end
  if texh_perfect then
    code:write(' + ((iv&' .. ((1<<texh_pow2)-1) .. ')')
  else
    code:write(' + ((v)')
  end
  if texw_perfect then
    code:write('<<' .. texw_pow2 .. ');\n')
  else
    code:write('*' .. texw .. ');\n')
  end
  code:write('    }\n')
end
code:write('  }\n') -- switch

-- wait one cycle
code:write('++:\n')

-- light
code:write('  lit = (light<<8);\n')
-- read data and query colormap
if ALL_IN_ONE then
  code:write('  colormap.addr = textures.rdata + lit;\n')
else
  code:write('  switch (texid) {\n')
  code:write('    default : { }\n')  
  for tex,id in pairs(texture_ids) do
    code:write('    case ' .. (id) .. ': {\n')
    if tex == 'F_SKY1' then -- special case for sky
      code:write('       colormap.addr = 94;\n')
    else
      code:write('       colormap.addr = texture_' .. tex .. '.rdata + lit;\n')
    end
    code:write('    }\n')
  end
  code:write('  }\n') 
end

-- wait one cycle
code:write('++:\n')

-- done!
code:write('palidx = colormap.rdata;\n')

code:write('}\n')
code:close()

-- now load file into string
local code = assert(io.open(path .. 'texturechip.ice', 'r'))
texturechip = code:read("*all")
code:close()

print('stored ' .. texture_start_addr .. ' texture bytes\n')