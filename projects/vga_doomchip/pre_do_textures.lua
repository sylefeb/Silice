-- -------------------------------------
-- palette
local in_pal = assert(io.open(findfile('PLAYPAL'), 'rb'))
local sz = fsize(in_pal)
print('palette file is ' .. sz .. ' bytes')
palette={}
inv_palette={}
for c=1,256 do
  local r = string.unpack('B',in_pal:read(1))
  local g = string.unpack('B',in_pal:read(1))
  local b = string.unpack('B',in_pal:read(1))
  local clr = r + (g*256) + (b*256*256)
  palette[c] = clr
  inv_palette[clr] = c
end

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
        save_table_as_image_with_palette(imgcur,palette,'textures/assembled/' .. current .. '.tga')
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
        local pimg = get_image_as_table('textures/source/' .. pname .. '.tga')
        local ppal = get_palette_as_table('textures/source/' .. pname .. '.tga')
        local ph = #pimg
        local pw = #pimg[1]
        print('   patch is ' .. pw .. 'x' .. ph)
        for j=1,ph do
          for i=1,pw do
             if ((j+y) <= #imgcur) and ((i+x) <= #imgcur[1]) and (j+y) > 0 and (i+x) > 0 then
               local clr  = ppal[1+pimg[j][i]]
               local pidx = inv_palette[clr]
               if not pidx then
                 error('color not found')
               end
               imgcur[math.floor(j+y)][math.floor(i+x)] = pidx-1
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
  save_table_as_image_with_palette(imgcur,palette,'textures/assembled/' .. current .. '.tga')
  print('         ...done.')
end 

print('num tex defs used: ' .. num_tex_defs)
--for p,i in pairs(texpatches) do
--  print('patch ' .. p .. ' used ' .. i .. ' times')
--end

-- error('stop')

