-- @sylefeb
-- include ASM code as a BROM
-- MIT license, see LICENSE_MIT in Silice repo root

if not path then
  path,_1,_2 = string.match(findfile('Makefile'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
	if path == '' then
	  path = '.'
	end
  print('********************* compiled code read from ' .. path .. '/firmware/code*.hex')
end

local in_asm = io.open(findfile('./firmware/code.hex'), 'r')
if not in_asm then
  error('please compile code first using the Makefile in ./firmware')
end

meminit = '{' -- exposed to the outside for BRAM initializ

local code = in_asm:read("*all")
in_asm:close()
local nbytes = 0
local h32 = ''
local numwords = 0
local first_line = true
local word = ''
local written = 0

for str in string.gmatch(code, "([^ \r\n]+)") do
  if string.sub(str,1,1) == '@' then
    if not first_line then -- we ignore global offset to code, allowing for the
                           -- BRAM/SPRAM trick where the bootsector is offset
                           -- in RAM (icebreaker) ; likely not portable...
      addr = tonumber(string.sub(str,2), 16)
      print('addr delta = ' .. addr - written)
      delta = addr - written
      for i=1,delta do
        -- pad with zeros
        word     = '00' .. word;
        if #word == 8 then
          meminit = meminit .. '32h' .. word .. ','
          word = ''
          numwords = numwords + 1
        end
      end
    end
  else
    h32 = str .. h32
    nbytes  = nbytes + 1
    written = written + 1
    if nbytes == 4 then
      print('32h' .. h32)
      meminit = meminit .. '32h' .. h32 .. ','
      nbytes = 0
      h32 = ''
      numwords = numwords + 1
    end
  end
  first_line = false
end

code_size_bytes = numwords * 4
print('code size: ' .. numwords .. ' 32bits words ('
      .. code_size_bytes .. ' bytes)')
meminit = meminit .. 'pad(uninitialized)}'
