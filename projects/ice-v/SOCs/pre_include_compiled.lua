-- include ASM code as a BROM
-- MIT license, see LICENSE_MIT in Silice repo root

if not path then
  path,_1,_2 = string.match(findfile('Makefile'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
	if path == '' then
	  path = '.'
	end
  print('********************* firmware written to     ' .. path .. '/data.img')
  print('********************* compiled code read from ' .. path .. '/compile/build/code*.hex')
end

in_asm = io.open(findfile('../compile/build/code.hex'), 'r')
if not in_asm then
  error('please compile code first using the compile_asm.sh / compile_c.sh scripts')
end
code = in_asm:read("*all")
in_asm:close()
nentries     = 0
nbytes       = 0
h32 = ''
meminit      = '{'
numwords     = 0
datainit     = '{'
datanumwords = 0
addr         = 0
if not data_addr then
  data_addr = 1<<31
end
local first_line = true
local word = ''
local written = 0
local out   = assert(io.open(path .. '/data.img', "wb"))

for str in string.gmatch(code, "([^ \r\n]+)") do
  if string.sub(str,1,1) == '@' then
    if not first_line then -- we ignore global offset to code, allowing for the
                           -- BRAM/SPRAM trick where the bootsector is offset
                           -- in RAM (icebreaker) ; likely not portable...
      local prev_addr = addr
      addr = tonumber(string.sub(str,2), 16)
      print('addr =  ' .. addr)
      if prev_addr < data_addr and addr >= data_addr then
        written = 0
      end
      if addr >= data_addr then
        delta = addr - data_addr - written
      else
        delta = addr - written
      end
      print('delta = ' .. addr - written)
      for i=1,delta do
        -- pad with zeros
        word     = '00' .. word;
        if #word == 8 then
          if addr >= data_addr then
            datainit = datainit .. '32h' .. word .. ','
            datanumwords = datanumwords + 1
          else
            meminit  = meminit  .. '32h' .. word .. ','
            numwords = numwords + 1
          end
          word = ''
        end
        out:write(string.pack('B', 0 ))
      end
    end
  else
    h32 = str .. h32
    out:write(string.pack('B', tonumber(str,16) ))
    nbytes  = nbytes + 1
    written = written + 1
    if nbytes == 4 then
      print('32h' .. h32)
      print("addr: " .. addr)
      if addr >= data_addr then
        datainit = datainit .. '32h' .. h32 .. ','
        datanumwords = datanumwords + 1
      else
        meminit  = meminit  .. '32h' .. h32 .. ','
        numwords = numwords + 1
      end
      nbytes = 0
      h32 = ''
    end
  end
  first_line = false
end

out  :close()

code_size_bytes = numwords * 4
print('code size: ' .. numwords .. ' 32bits words ('
      .. code_size_bytes .. ' bytes)')
data_size_bytes = datanumwords * 4
print('dara size: ' .. datanumwords .. ' 32bits words ('
      .. data_size_bytes .. ' bytes)')
meminit  = meminit  .. 'pad(uninitialized)}'
datainit = datainit .. 'pad(uninitialized)}'
