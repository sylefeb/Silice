-- Temporary solution to extract MIF files for bram initialization
-- @sylefeb, August 2020

brams  = {}
values = {}

-- parse VQM file to gather parameters
for line in io.lines("build0.vqm") do

  local name,param,value = line:match("defparam (%S+) .(%S+) = ([^%s;]+)")  
  if name then
    name = name:sub(2)
    if not values[name] then
      values[name] = {}
    end
    values[name][param] = value
    if param == "mem_init0" then
      brams[1+#brams] = name
      --print('name' .. name)
      --print('   ' .. param .. '    ' .. value)
    end
  end

end

-- write one MIF file for each BRAM
for _,name in ipairs(brams) do
  local file = io.open(name .. '.mif',"w")
  io.output(file)
  print('writing MIF file for bram ' .. name)
  io.write('WIDTH='..values[name]['port_a_logical_ram_width']..';\n')
  io.write('DEPTH='..values[name]['port_a_logical_ram_depth']..';\n')
  io.write('ADDRESS_RADIX=UNS;\n')
  io.write('DATA_RADIX=BIN;\n')
  io.write('CONTENT BEGIN\n')  
  local depth = math.floor(values[name]['port_a_logical_ram_depth'])
  local width = math.floor(values[name]['port_a_logical_ram_width'])
  local bitstream = values[name]['mem_init0']:sub(8) -- skip 10240'b prefix
  assert(#bitstream == 10240,'initialization vectors has an incorrect size (expecting 10240 bits)')
  local skip = 10240 - depth*width
  bitstream = bitstream:sub(1+skip)
  for i=depth-1,0,-1 do
    local bits = bitstream:sub(1,width)
    bitstream = bitstream:sub(1+width)
    io.write('  ' .. i .. ' :  ' .. bits:gsub('x','0') .. ';\n')
  end
  io.write('END;\n')
  file:close()
end

-- now rewrite the VQM file
print('producing patched VQM file')
local file = io.open('build1.vqm',"w")
io.output(file)
for line in io.lines("build0.vqm") do
  local init = line:match("defparam (%S+) .mem_init0")  
  if init then 
    init = init:sub(2)
    io.write('  defparam \\' .. init .. ' .init_file = \"' .. init .. '.mif\";\n')
    io.write('  defparam \\' .. init .. ' .init_file_layout = \"port_a\";\n')
  else
    io.write(line)
    io.write('\n')
  end
end
file:close()

os.execute("mv build0.vqm build1.vqm.bak")

print('done.')
