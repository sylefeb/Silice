-- include ASM code as a BROM

path,_1,_2 = string.match(findfile('pre_include_asm.lua'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
print('PATH is ' .. path)

data_hex = ''
init_data_bytes = 0
prev_addr = -1

local out = assert(io.open(path .. '/data.img', "wb"))
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
        prev_addr = prev_addr + 1
      end
      prev_addr = addr
    else 
      data_hex = data_hex .. '8h' .. str .. ','
      out:write(string.pack('B', tonumber(str,16) ))
      init_data_bytes = init_data_bytes + 1
      prev_addr = prev_addr + 1
    end
  end

end

-- pad with zeros until 128KB
-- so we can append other stuff after!
sdcard_size = init_data_bytes
while sdcard_size < (1<<17) do
  out:write(string.pack('B', 0 ))
  sdcard_size = sdcard_size + 1
  data_hex = data_hex .. '8h0,'
end

-- DEBUG
--for i=0,256 do  
--  data_hex = data_hex .. '8d' .. i .. ','
--end

out:close()

print('sdcard image is ' .. init_data_bytes .. ' bytes.')

init_data_bytes = math.max(init_data_bytes,(1<<20)) -- we load 1 MB to be sure we can append stuff

-- error('stop')
