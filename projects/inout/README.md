# How to use inout

This example uses a PMOD configured as an `inout` and demonstrates the syntax
to select the `inout` as an output or input (high impedance).

See code in [inout.si](inout.si).

The `inout` variable is `pmod`. The bit vector `pmod.oenable` allows to select
which bits are outputs (`1`) or inputs (`0`). Then, `pmod.o` can be set to the
desired output value (which is ignored if configured as input, hence the use of
`x` in the bit vectors, but that could be anything). To read a bit use `pmod.i`.

> **Note:** The tristate outputs are registered by Silice, meaning that when setting `pmod.o` and `pmod.oenable`, the change will be reflected on the pin at the next positive clock edge. If required, this can be avoided by feeding the inout pin into an imported Verilog module defining the desired behavior. Using an imported Verilog module also allows feeding the pin in specialized vendor blocks.