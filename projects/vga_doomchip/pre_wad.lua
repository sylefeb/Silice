-- SL 2020-05, DooM-Chip WAD lump extractor

-- -------------------------------------
-- helper for file size
function fsize(file)
  local start = file:seek()
  local size  = file:seek("end")
  file:seek("set", start)
  return size
end

lump_level = {
LINEDEFS='LINEDEFS',
NODES='NODES',
SECTORS='SECTORS',
SEGS='SEGS',
SIDEDEFS='SIDEDEFS',
SSECTORS='SSECTORS',
THINGS='THINGS',
VERTEXES='VERTEXES',
}

lump_misc = {
'COLORMAP',
'PLAYPAL',
}

-- -------------------------------------

local in_wad = assert(io.open(findfile(wad), 'rb'))
local sz_wad = fsize(in_wad)

local id = string.unpack('c4',in_wad:read(4))
if id ~= 'IWAD' and  id ~= 'PWAD' then
  error('not a WAD file')
end

local nlumps = string.unpack('I4',in_wad:read(4))
print('WAD file contains ' .. nlumps .. ' lumps')

local diroffs = string.unpack('I4',in_wad:read(4))
-- read directory
in_wad:seek("set", diroffs)
local level_prefix = ''
lumps={}
for l=1,nlumps do
  local start = string.unpack('I4',in_wad:read(4))
  local size  = string.unpack('I4',in_wad:read(4))
  local name  = string.unpack('c8',in_wad:read(8)):match("[%_-%a%d]+")
  if string.match(name,'E%dM%d') then
    print('level ' .. name)
    level_prefix = name
  end
  if lump_level[name] then
    name = level_prefix .. '_' .. name
  end
  lumps[name] = { start=start, size=size }
  print(' - lump "' .. name .. '" [' .. start .. '] ' .. size)
end

in_wad:close()

-- -------------------------------------
-- extracts a lump
function extract_lump(name)
  name = name:upper()
  -- get script path
  local path,_1,_2 = string.match(findfile('vga_doomchip.ice'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
  if path == '' then path = '.' end
  -- open wad
  local in_wad = assert(io.open(findfile(wad), 'rb'))
  print('extracting lump ' .. name)
  if lumps[name] then
    in_wad:seek("set", lumps[name].start)
    local data = in_wad:read(lumps[name].size)
    local out_lump = assert(io.open(path .. '/lumps/' .. name .. '.lump', 'wb'))
    out_lump:write(data)
    out_lump:close()
  else
    error('lump ' .. name .. ' not found!')
  end
  in_wad:close()
end

-- -------------------------------------
-- extract misc lumps
for _,lmp in pairs(lump_misc) do
  extract_lump(lmp)
end

for _,lmp in pairs(lump_level) do
  extract_lump(level .. '_' .. lmp)
end

-- error('stop')

