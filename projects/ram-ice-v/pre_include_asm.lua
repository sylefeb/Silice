-- include ASM code as a BROM
memsize = 1024

path,_1,_2 = string.match(findfile('pre_include_asm.lua'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
print('PATH is ' .. path)

in_asm = io.open(findfile('build/code.hex'), 'r')
if not in_asm then
  error('please compile code first using the compile_asm.sh / compile_c.sh scripts')
end
code = in_asm:read("*all")
in_asm:close()
nentries = 0
nbytes = 0
h32 = ''
meminit = '{'
numinit = 0
data_hex = ''
init_data_bytes = 0
local out = assert(io.open(path .. '/data.img', "wb"))
for str in string.gmatch(code, "([^ \r\n]+)") do
  -- 
  if nentries > 0 then
    data_hex = data_hex .. '8h' .. str .. ','
    out:write(string.pack('B', tonumber(str,16) ))
    init_data_bytes = init_data_bytes + 1
    h32 = str .. h32
    nbytes = nbytes + 1
    if nbytes == 4 then
      print('32h' .. h32)
      meminit = meminit .. '32h' .. h32 .. ','
      nbytes = 0
      h32 = ''
      numinit = numinit + 1
    end
  end
  nentries = nentries + 1
end
out:close()

for i=numinit+1,memsize do
  meminit = meminit .. '32h0,'
end
meminit = meminit .. '}'

-- init_data_bytes = 512 + init_data_bytes
