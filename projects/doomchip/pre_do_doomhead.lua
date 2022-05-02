-- @sylefeb, 2020
-- MIT license, see LICENSE_MIT in Silice repo root

print('preparing doomhead')

-- -------------------------------------
-- palette
local in_pal = assert(io.open(findfile('lumps/PLAYPAL.lump'), 'rb'))
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
path,_1,_2 = string.match(findfile('vga_doomchip.si'), "(.-)([^\\/]-%.?([^%.\\/]*))$")

doomhead_lumps = {
'STFST01',
'STFST00',
'STFST02'
}

-- -------------------------------------
-- produce the doomhead brom
print('generating doomhead brom code')
local code = assert(io.open(path .. 'doomhead.si', 'w'))
local doomface_start = 0
doomface_nfo = {}
code:write('brom uint8 doomhead[] = {\n')
for i,name in ipairs(doomhead_lumps) do
  extract_lump(name,'')
  local texdata = decode_patch_lump(path .. 'lumps/' .. name .. '.lump')
  local texw = #texdata[1]
  local texh = #texdata
  for j=1,texh do
    for i=1,texw do
      code:write('8h'..string.format("%02x",texdata[j][i]):sub(-2) .. ',')
    end
  end
  doomface_nfo[i] = {
    start  = doomface_start,
    width  = texw,
    height = texh
  }
  local doomface_size = texw*texh
  doomface_start = doomface_start + doomface_size
end
code:write('};\n')
code:write('uint32 doomface_nfo[] = {\n')
for _,nfo in ipairs(doomface_nfo) do
  bin = '32h'
      .. string.format("%02x",nfo.height):sub(-2) -- 8 bits
      .. string.format("%02x",nfo.width):sub(-2)  -- 8 bits
      .. string.format("%04x",nfo.start):sub(-4)  -- 16 bits
  code:write(bin .. ',')
end
code:write('};')

-- done
code:close()

-- now load file into string
local code = assert(io.open(path .. 'doomhead.si', 'r'))
doomhead = code:read("*all")
code:close()
