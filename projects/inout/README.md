# How to use inout

This example uses a PMOD configured as an `inout` and demonstrates the syntax
to select the `inout` as an output or input (high impedance).

See code in [inout.ice](inout.ice).

The `inout` variable is `pmod`. The bit vector `pmod.oenable` allows to select
which bits are outputs (`1`) or inputs (`0`). Then, `pmod.o` can be set to the
desired output value (which is ignored of configured as input, hence the use of 
`x` in the bit vectors, but that could be anything). To read a bit use `pmod.i`.
