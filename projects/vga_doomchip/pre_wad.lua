-- SL 2020-05, DooM-Chip WAD lump extractor

-- -------------------------------------
-- helper for file size
function fsize(file)
  local start = file:seek()
  local size  = file:seek("end")
  file:seek("set", start)
  return size
end

-- -------------------------------------
local in_wad = assert(io.open(findfile(wad), 'rb'))
local sz_wad = fsize(in_wad)
print('WAD file is ' .. sz_wad .. ' bytes')

local id = string.unpack('c4',in_wad:read(4))
if id ~= 'IWAD' and  id ~= 'PWAD' then
  error('not a WAD file')
end

local nlumps = string.unpack('I4',in_wad:read(4))
print(' - ' .. nlumps .. ' lumps')

local diroffs = string.unpack('I4',in_wad:read(4))
-- read directory
in_wad:seek("set", diroffs)
lumps={}
for l=1,nlumps do
  local seek = string.unpack('I4',in_wad:read(4))
  local size = string.unpack('I4',in_wad:read(4))
  local name = string.unpack('c8',in_wad:read(8)):match("[%_-%a%d]+")
  print(' - lump ' .. name .. ' [' .. seek .. '] ' .. size)
end

in_wad:close()

error('stop')