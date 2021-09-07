platforms = {'unknown-elf','linux-elf','unknown-gnu','linux-gnu'}

function set_toolchain_names(platform)
  gcc = 'riscv64-' .. platform .. '-gcc'
  as  = 'riscv64-' .. platform .. '-as'
  ld  = 'riscv64-' .. platform .. '-ld'
  oc  = 'riscv64-' .. platform .. '-objcopy'
end

-- =========================================================================

function find_toolchain()
  for _,p in pairs(platforms) do    
    set_toolchain_names(p)
    if test_toolchain() then
      return true
    end
  end
  error('RISC-V toolchain not found')
end

-- =========================================================================
 
function test_toolchain()
  local h  = io.popen(gcc .. ' --version','r')
  local r  = h:read('*all')
  h:close()
  if r == '' then
    return false
  else
    return true
  end
end

-- =========================================================================

function compile(file)
  print('********************* compiling from      ' .. file)
  local cmd
  cmd =  gcc .. ' '
      .. '-fno-builtin -fno-unroll-loops -O1 -fno-pic -march=rv32i -mabi=ilp32 -c -o code.o '
      .. SRC
  os.execute(cmd)
  cmd =  as .. ' '
      .. '-march=rv32i -mabi=ilp32 '
      .. '--defsym STACK_START=' .. STACK_START .. ' '
      .. '--defsym STACK_SIZE=' .. STACK_SIZE .. ' '
      .. '-o crt0.o '
      .. CRT0
  os.execute(cmd)
  cmd =  ld .. ' '
      .. '-m elf32lriscv -b elf32-littleriscv -T' .. LD_CONFIG .. ' --no-relax -o code.elf code.o'
  os.execute(cmd)
  cmd =  oc .. ' '
      .. '-O verilog code.elf code.hex'
  os.execute(cmd)
end

-- =========================================================================

function to_BRAM()
  if not path then
    path,_1,_2 = string.match(findfile('code.hex'), "(.-)([^\\/]-%.?([^%.\\/]*))$")
    if path == '' then 
      path = '.'
    end
    print('********************* firmware written to     ' .. path .. '/code.bin')
    print('********************* compiled code read from ' .. path .. '/code.hex')
  end
  all_data_hex  = {}
  all_data_bram = {}
  word = ''
  init_data_bytes = 0
  local prev_addr = -1
  local out       = assert(io.open(path .. '/data.bin', "wb"))
  local in_asm    = io.open(findfile('code.hex'), 'r')
  if not in_asm then
    error('C code compilation failed')
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

  out:close()
  data_hex  = table.concat(all_data_hex)
  data_bram = table.concat(all_data_bram)

end

-- =========================================================================

-- print('source file = ' .. SRC)

find_toolchain()

compile(SRC)

to_BRAM()
