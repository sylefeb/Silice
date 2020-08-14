print('preparing sdcard image')

local path,_1,_2 = string.match(findfile('test.tga'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
  if path == '' then path = '.' end

img = get_image_as_table(findfile('test.tga'))
pal = get_palette_as_table(findfile('test.tga'))

local out = assert(io.open(path .. '/raw.img', "wb"))
for _,p in ipairs(pal) do
  out:write(string.pack('I3',p))
end
print('image is ' .. #img .. 'x' .. #img[1])
for _,r in ipairs(img) do
  for _,v in ipairs(r) do
    out:write(string.pack('B',v))
  end
end
out:close()
