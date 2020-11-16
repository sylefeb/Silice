-- include ASM code as a BROM
memsize = 1024

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
for str in string.gmatch(code, "([^ \r\n]+)") do
  -- 
  if nentries > 0 then
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

for i=numinit+1,memsize do
  meminit = meminit .. '32h0,'
end
meminit = meminit .. '}'
