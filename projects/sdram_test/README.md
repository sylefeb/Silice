# SDRAM test

Shows how to bind a verilog SDRAM simulator. Meant to be simulated with the icarus_bare framework.

Uses Alchitry Mojo SDRAM controller (sdram.v) as well as the Micron Semiconductor SDRAM model (mt48lc32m8a2.v).

The SDRAM model Semiconductor cannot be directly imported (too complex for silice's simple Verilog parser) and is instead wrapped into a simple 'simul_sdram.v' module. 

mt48lc32m8a2.v is appended to the silice project (silice does not parse it, it simply copies it), while the simul_sdram.v wrapper is imported.
