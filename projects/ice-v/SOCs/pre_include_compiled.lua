-- include ASM code as a BROM
memsize = 1536 -- max on an icestick

in_asm = io.open(findfile('../compile/build/code.hex'), 'r')
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
local word = ''
local prev_addr = -1

for str in string.gmatch(code, "([^ \r\n]+)") do
 if string.sub(str,1,1) == '@' then
    addr = tonumber(string.sub(str,2), 16)
    if prev_addr < 0 then
      print('first addr = ' .. addr)
      prev_addr = addr
    end
    print('addr delta = ' .. addr - prev_addr)
    delta = addr - prev_addr
    for i=1,delta do
      -- pad with zeros
      word     = '00' .. word;
      if #word == 8 then 
        meminit = meminit .. '32h' .. word .. ','
        word = ''
        numinit = numinit + 1
      end
      prev_addr       = prev_addr + 1
    end
    prev_addr = addr
  else 
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
end

print('code size: ' .. numinit .. ' 32bits words')
if numinit > memsize then
  error('too much code!')
end
code_size_bytes = numinit * 4
meminit = meminit .. 'pad(uninitialized)}'
