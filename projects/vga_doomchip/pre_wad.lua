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
print('WAD file is ' .. sz .. ' bytes')

local id = string.unpack('h',in_verts:read(4))
if (id[0] ~= 'I' and id[0] ~= 'P') or  id[0] ~= 'I' or id[0] ~= 'I' or id[0] ~= 'I' then
  error('not a WAD file')
end
