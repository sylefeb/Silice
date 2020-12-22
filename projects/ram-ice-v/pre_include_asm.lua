-- include ASM code as a BROM
memsize = 1024

path,_1,_2 = string.match(findfile('pre_include_asm.lua'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
print('PATH is ' .. path)

nbytes = 0
h32 = ''
meminit = '{'
numinit = 0
data_hex = ''
init_data_bytes = 0
prev_addr = -1
for cpu=0,1 do
  in_asm = io.open(findfile('build/code' .. cpu .. '.hex'), 'r')
  if not in_asm then
    if cpu == 0 then
      error('please compile code first using the compile_asm.sh / compile_c.sh scripts')
    else
      break
    end
  end
  code = in_asm:read("*all")
  in_asm:close()
  local out = assert(io.open(path .. '/data.img', "wb"))
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
        data_hex = data_hex .. '8h' .. 0 .. ','
        out:write(string.pack('B', 0 ))
        init_data_bytes = init_data_bytes + 1
        h32 = str .. h32
        nbytes = nbytes + 1
        prev_addr = prev_addr + 1
      end
      prev_addr = addr
    else 
      data_hex = data_hex .. '8h' .. str .. ','
      out:write(string.pack('B', tonumber(str,16) ))
      init_data_bytes = init_data_bytes + 1
      h32 = str .. h32
      nbytes = nbytes + 1
      prev_addr = prev_addr + 1
      if nbytes == 4 then
        -- print('32h' .. h32)
        meminit = meminit .. '32h' .. h32 .. ','
        nbytes = 0
        h32 = ''
        numinit = numinit + 1
      end
    end
  end
  out:close()

  for i=numinit+1,memsize do
    meminit = meminit .. '32h0,'
  end
  meminit = meminit .. '}'

end

-- error('stop')