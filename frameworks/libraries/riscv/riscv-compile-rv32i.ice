$$dofile('riscv-compile.lua')

$$addrW    = 14
$$memsz    = 1024//4
$$meminit  = data_bram
$$external = 10
$$io_decl  = 'output uint32 leds'

$include('riscv-soc.ice')
