-- include ASM code as a BROM

if not path then
  path,_1,_2 = string.match(findfile('Makefile'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
	if path == '' then 
	  path = '.'
	end
  print('********************* firmware written to     ' .. path .. '/data.img')
  print('********************* compiled code read from ' .. path .. '/build/code*.hex')
end

all_data_hex   = {}
all_data_bram = {}
word = ''
init_data_bytes = 0
local prev_addr = -1

local out = assert(io.open(path .. '/data.img', "wb"))
for cpu=0,1 do
  local in_asm = io.open(findfile('build/code' .. cpu .. '.hex'), 'r')
  if not in_asm then
    if cpu == 0 then
      error('please compile code first using the compile_asm.sh / compile_c.sh scripts')
    else
      break
    end
  end
  local code = in_asm:read("*all")
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
        word     = '00' .. word;
        if #word == 8 then 
          all_data_bram[1+#all_data_bram] = '32h' .. word .. ','
          word = ''
        end
        all_data_hex[1+#all_data_hex] = '8h' .. 0 .. ','
        out:write(string.pack('B', 0 ))
        init_data_bytes = init_data_bytes + 1
        prev_addr       = prev_addr + 1
      end
      prev_addr = addr
    else 
      word     = str .. word;
      if #word == 8 then 
        all_data_bram[1+#all_data_bram] = '32h' .. word .. ','
        word = ''
      end
      all_data_hex[1+#all_data_hex] = '8h' .. str .. ','
      out:write(string.pack('B', tonumber(str,16) ))
      init_data_bytes = init_data_bytes + 1
      prev_addr       = prev_addr + 1
    end
  end

end

-- pad with zeros until 128KB
-- so we can append other stuff after!
if not sdcard_image_pad_size then
  sdcard_image_pad_size = (1<<17)
end
print('pad size is ' .. sdcard_image_pad_size .. ' bytes')

sdcard_size = init_data_bytes
while sdcard_size < sdcard_image_pad_size do
  out:write(string.pack('B', 0 ))
  sdcard_size = sdcard_size + 1
  all_data_hex[1+#all_data_hex] = '8h0,'
end

if sdcard_extra_files then
  for _,fname in pairs(sdcard_extra_files) do
    print('adding file ' .. fname)
    local inp = assert(io.open(path .. fname, "rb"))
    while true do
      local r = inp:read(1)
      if not r then break end
      local b = string.unpack('B',r)
      all_data_hex[1+#all_data_hex] = '8h' .. string.format("%02x",b):sub(-2) .. ','
    end
    inp:close()
  end
else
  print('no extra files')  
end

out:close()

data_hex  = table.concat(all_data_hex)
data_bram = table.concat(all_data_bram)

print('sdcard image is ' .. init_data_bytes .. ' bytes.')
