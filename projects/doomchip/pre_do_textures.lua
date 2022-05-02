-- @sylefeb, 2020
-- MIT license, see LICENSE_MIT in Silice repo root

print('preparing textures')

if SIMULATION then
  USE_BRAM = false -- RAM or ROM
  memory_budget_bits = 2000000 -- 4000000
  reduce_switches    = true
  default_shrink     = 2 -- 2 is very low res, for quicker testing, use 0 for native res
else
  USE_BRAM = false -- RAM or ROM
  memory_budget_bits = 500000 -- 3000000
  reduce_switches    = true
  default_shrink     = 0 -- 2 is very low res, for quicker testing, use 0 for native res
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
-- get script path
path,_1,_2 = string.match(findfile('vga_doomchip.si'), "(.-)([^\\/]-%.?([^%.\\/]*))$")

-- -------------------------------------
-- parse pnames
local in_pnames = assert(io.open(findfile('lumps/PNAMES.lump'), 'rb'))
local num_pnames = string.unpack('I4',in_pnames:read(4))
pnames={}
for p=1,num_pnames do
  local name = in_pnames:read(8):match("[%_-%a%d]+")
  pnames[p-1] = name
end
in_pnames:close()

-- -------------------------------------
-- parse texture defs
--
function parse_textures(texdeflump)
  local in_texdefs = io.open(findfile('lumps/' .. texdeflump), 'rb')
  if in_texdefs == nil then
    return -- not all WADs contain TEXTURE2, for instance
  end
  local imgcur = nil
  local imgcur_w = 0
  local imgcur_h = 0
  local sz_read = 0
  local num_texdefs = string.unpack('I4',in_texdefs:read(4))
  local texdefs_seek={}
  for i=1,num_texdefs do
    texdefs_seek[i] = string.unpack('I4',in_texdefs:read(4))
  end

  for i=1,num_texdefs do
    local name = in_texdefs:read(8):match("[%_-%a%d]+")
    in_texdefs:read(2) -- skip
    in_texdefs:read(2) -- skip
    local w = string.unpack('H',in_texdefs:read(2))
    local h = string.unpack('H',in_texdefs:read(2))
    in_texdefs:read(2) -- skip
    in_texdefs:read(2) -- skip
    -- start new
    print('wall texture ' .. name .. ' ' .. w .. 'x' .. h)
    imgcur = {}
    for j=1,h do
      imgcur[j] = {}
      for i=1,w do
        imgcur[j][i] = -1
      end
    end
    -- tex is opaque?
    local npatches = string.unpack('H',in_texdefs:read(2))
    -- copy patches
    for p=1,npatches do
      local x   = string.unpack('h',in_texdefs:read(2))
      local y   = string.unpack('h',in_texdefs:read(2))
      local pid = string.unpack('H',in_texdefs:read(2))
      pname = nil
      if pnames[pid] then
        pname = pnames[pid]
        print('   patch "' .. pname .. '" id=' .. pid)
        print('     x:  ' .. x)
        print('     y:  ' .. y)
      end
      in_texdefs:read(2) -- skip
      in_texdefs:read(2) -- skip
      if pname then
        print('   loading patch ' .. pname)
        local pimg = decode_patch_lump(path .. 'lumps/patches/' .. pname:upper() .. '.lump')
        local ph = #pimg
        local pw = #pimg[1]
        print('   patch is ' .. pw .. 'x' .. ph)
        for j=1,ph do
          for i=1,pw do
             if ((j+y) <= #imgcur) and ((i+x) <= #imgcur[1]) and (j+y) > 0 and (i+x) > 0 then
               if pimg[j][i] > -1 then -- -1 is transparent
                 imgcur[math.floor(j+y)][math.floor(i+x)] = pimg[j][i]
               end
             end
          end
        end
        print('   copied.')
      else
        error('cannot find patch ' .. pid)
      end
    end
    local opaque = 1
    local uses_255 = 0
    for j=1,h do
      for i=1,w do
        if imgcur[j][i] == 255 then
          uses_255 = 1
        end
        if imgcur[j][i] == -1 then
          opaque = 0
          imgcur[j][i] = 255 -- replace by transparent marker
        end
      end
    end
    textures_opacity[name] = opaque
    -- save
    print('saving ' .. name .. ' ...')
    save_table_as_image_with_palette(imgcur,palette,path .. 'textures/assembled/' .. name:upper() .. '.tga')
    print('         ... done.')

    if opaque == 0 and uses_255 == 1 then
      print('WARNING: transparent marker used in texture')
    end
  end
end

textures_opacity={}
parse_textures('TEXTURE1.lump')
parse_textures('TEXTURE2.lump')

-- -------------------------------------
-- add texture sizes to datastrcuture

for tex,nfo in pairs(texture_ids) do
  local texdata
  if nfo.type == 'wall' then
    texdata = get_image_as_table(path .. 'textures/assembled/' .. tex:upper() .. '.tga')
  else
    texdata = decode_flat_lump(path .. 'lumps/flats/' .. tex .. '.lump')
  end
  texture_ids[tex].texw = #texdata[1]
  texture_ids[tex].texh = #texdata
end
-- -------------------------------------
-- decide which textures to shrink
shrink_below_usage = 0
shrink_min_res = 256
max_usage = 0
for tex,nfo in pairs(texture_ids) do
  max_usage = math.max(max_usage,nfo.used)
end
-- auto reduction
repeat
  num_reduced = 0
  texture_bits = 0
  texture_shrink = {}
  for tex,nfo in pairs(texture_ids) do
    if tex ~= 'F_SKY1' then -- skip sky entirely
      texture_shrink[tex] = default_shrink -- default
      local is_switch = (tex:sub(1,3) == 'SW1' or tex:sub(1,3) == 'SW2')
      if      nfo.used < shrink_below_usage
          and math.max(nfo.texw,nfo.texh) >= shrink_min_res
          and (not is_switch or reduce_switches)
        then
        texture_shrink[tex] = 1+default_shrink -- shrink it in half
        num_reduced = num_reduced + 1
        --print('reducing size of texture ' .. tex .. ' (' .. nfo.texw .. 'x' .. nfo.texh .. ' used ' .. nfo.used .. ' times)')
      end
      texture_bits = texture_bits + (nfo.texw>>texture_shrink[tex])*(nfo.texh>>texture_shrink[tex])*8
    end
  end
  shrink_below_usage = shrink_below_usage + 1
  if shrink_below_usage > max_usage then
    shrink_below_usage = 0
    shrink_min_res = shrink_min_res // 2
    if (shrink_min_res == 0) then
      print('giving up')
      break
    end
    print('restart -- current texture bits: ' .. texture_bits
       .. ' budget: ' .. memory_budget_bits
       .. ' res cutoff ' .. shrink_min_res)
  end
until texture_bits < memory_budget_bits
print('texture bits: ' .. texture_bits
       .. ' budget: ' .. memory_budget_bits
       .. ' num reduced: ' .. num_reduced .. '/' .. num_textures)

-- error('stop')

-- -------------------------------------
-- produce code for the texture chip
print('generating texture chip code')
local code = assert(io.open(path .. 'texturechip.si', 'w'))
code:write([[algorithm texturechip(
  input  uint8 texid,
  input  int9  iiu,
  input  int9  iiv,
  output uint8 palidx,
  output uint1 opac) {
  ]])
-- build bram and texture start address table
code:write('  uint8  u    = 0;\n')
code:write('  uint8  v    = 0;\n')
code:write('  int9   iu   = 0;\n')
code:write('  int9   iv   = 0;\n')
code:write('  int9   nv   = 0;\n')
texture_start_addr = 0
texture_start_addr_table = {}
if ALL_IN_ONE then
  if USE_BRAM then
    code:write('  bram uint8 textures[] = {\n')
  else
    code:write('  brom uint8 textures[] = {\n')
  end
end
for tex,nfo in pairs(texture_ids) do
  if tex ~= 'F_SKY1' then -- skip sky entirely
    -- load texture
    local texdata
    if nfo.type == 'wall' then
      texdata = get_image_as_table(path .. 'textures/assembled/' .. tex:upper() .. '.tga')
    else
      texdata = decode_flat_lump(path .. 'lumps/flats/' .. tex .. '.lump')
    end
    if texture_shrink[tex] == 3 then
      texdata = shrink_tex(shrink_tex(shrink_tex(texdata)))
    elseif texture_shrink[tex] == 2 then
      texdata = shrink_tex(shrink_tex(texdata))
    elseif texture_shrink[tex] == 1 then
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
end
if ALL_IN_ONE then
  code:write('};\n')
end

-- addressing
code:write('  switch (texid) {\n')
code:write('    default : { }\n')
for tex,nfo in pairs(texture_ids) do
  if tex ~= 'F_SKY1' then -- skip sky entirely
    -- load texture
    local texdata
    if nfo.type == 'wall' then
      texdata = get_image_as_table(path .. 'textures/assembled/' .. tex:upper() .. '.tga')
    else
      texdata = decode_flat_lump(path .. 'lumps/flats/' .. tex .. '.lump')
    end
    if texture_shrink[tex] == 3 then
      texdata = shrink_tex(shrink_tex(shrink_tex(texdata)))
    elseif texture_shrink[tex] == 2 then
      texdata = shrink_tex(shrink_tex(texdata))
    elseif texture_shrink[tex] == 1 then
      texdata = shrink_tex(texdata)
    end
    local texw = #texdata[1]
    local texh = #texdata
    local texw_pow2,texw_perfect = texture_dim_pow2(texw)
    local texh_pow2,texh_perfect = texture_dim_pow2(texh)
    code:write('    case ' .. (nfo.id) .. ': {\n')
    code:write('       // ' .. tex .. ' ' .. texw .. 'x' .. texh .. '\n')
    if texture_shrink[tex] == 3 then
      code:write('  iu = iiu>>>3;\n')
      code:write('  iv = iiv>>>3;\n')
    elseif texture_shrink[tex] == 2 then
      code:write('  iu = iiu>>>2;\n')
      code:write('  iv = iiv>>>2;\n')
    elseif texture_shrink[tex] == 1 then
      code:write('  iu = iiu>>>1;\n')
      code:write('  iv = iiv>>>1;\n')
    else
      code:write('  iu = iiu;\n')
      code:write('  iv = iiv;\n')
    end
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
    code:write('     if (iv > 0) { nv = iv; } else { nv = ' .. texh ..  ' + iv; } \n')
    if not texh_perfect then
      code:write('     if (nv > ' .. (3*texh) ..') {\n')
      code:write('       v = nv - ' .. (3*texh) .. ';\n')
      code:write('     } else {\n')
      code:write('       if (nv > ' .. (2*texh) ..') {\n')
      code:write('         v = nv - ' .. (2*texh) .. ';\n')
      code:write('       } else {\n')
      code:write('         if (nv > ' .. (texh) ..') {\n')
      code:write('           v = nv - ' .. (texh) .. ';\n')
      code:write('         } else {\n')
      code:write('           v = nv;\n')
      code:write('         }\n')
      code:write('       }\n')
      code:write('     }\n')
    else
      code:write('     v = nv; \n')
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
      code:write(' + ((v&' .. ((1<<texh_pow2)-1) .. ')')
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
end
code:write('  }\n') -- switch

-- wait for texture data
code:write('++:\n')

-- defaut is non transparent
code:write('  opac = 1;')
-- read and return data
if ALL_IN_ONE then
  error('not implemented!')
else
  code:write('  switch (texid) {\n')
  code:write('    default : { palidx = 255; }\n')
  code:write('    case 0  : { palidx = 94; }\n')
  for tex,nfo in pairs(texture_ids) do
    code:write('    case ' .. (nfo.id) .. ': {\n')
    if tex == 'F_SKY1' then -- special case for sky
      code:write('       palidx = 94;\n')
    else
      if textures_opacity[tex] == 0 then
        code:write('       opac = texture_' .. tex .. '.rdata==255 ? 0 : 1;')
      end
      code:write('       palidx = texture_' .. tex .. '.rdata;\n')
    end
    code:write('    }\n')
  end
  code:write('  }\n')
end

code:write('}\n')

-- now make a circuit to tell which ids are on/off switches
-- switch ON
code:write('circuitry is_switch_on(input texid,output is)\n')
code:write('{\n')
code:write('  switch (texid) {\n')
code:write('    default : { is = 0; }\n')
for id,name in pairs(switch_on_ids) do
  code:write('    case ' .. id .. '  : { is = 1; }\n')
end
code:write('  }\n')
code:write('}\n')
-- switch OFF
code:write('circuitry is_switch_off(input texid,output is)\n')
code:write('{\n')
code:write('  switch (texid) {\n')
code:write('    default : { is = 0; }\n')
for id,name in pairs(switch_off_ids) do
  code:write('    case ' .. id .. '  : { is = 1; }\n')
end
code:write('  }\n')
code:write('}\n')
-- switch ON or OFF
code:write('circuitry is_switch(input texid,output is)\n')
code:write('{\n')
code:write('  switch (texid) {\n')
code:write('    default : { is = 0; }\n')
for id,name in pairs(switch_on_ids) do
  code:write('    case ' .. id .. '  : { is = 1; }\n')
end
for id,name in pairs(switch_off_ids) do
  code:write('    case ' .. id .. '  : { is = 1; }\n')
end
code:write('  }\n')
code:write('}\n')

-- circuit to know if a texture is transparent
code:write('circuitry is_opaque(input texid,output is)\n')
code:write('{\n')
code:write('  switch (texid) {\n')
code:write('    default : { is = 1; }\n')
for name,opaque in pairs(textures_opacity) do
  if opaque == 0 then
    if texture_ids[name] then
      code:write('    case ' .. texture_ids[name].id .. '  : { is = 0; }\n')
    end
  end
end
code:write('  }\n')
code:write('}\n')
code:write('// stored ' .. texture_start_addr .. ' texture bytes (' .. texture_start_addr*8 .. ' bits) \n')

-- colormap brom for lighting
colormap = '  brom   uint8 colormap[] = {\n'
for _,cmap in ipairs(colormaps) do
  for _,cidx in ipairs(cmap) do
    colormap = colormap .. '8h'..string.format("%02x",cidx):sub(-2) .. ','
  end
end
colormap = colormap .. '};\n'

-- done
code:close()

-- now load file into string
local code = assert(io.open(path .. 'texturechip.si', 'r'))
texturechip = code:read("*all")
code:close()

print('stored ' .. texture_start_addr .. ' texture bytes (' .. texture_start_addr*8 .. ' bits) \n')

-- error('stop')
