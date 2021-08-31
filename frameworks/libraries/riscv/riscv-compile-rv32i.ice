$$dofile('riscv-compile.lua')

$$addrW    = 14
$$memsz    = 1024//4
$$meminit  = 'file(\'data.bin\')'
$$external = 10
$$io_decl  = 'output uint32 leds'

$include('riscv-soc.ice')
