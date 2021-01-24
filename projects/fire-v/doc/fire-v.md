# The Fire-V RV32I core

This is a RV32I core with the following characteristics:
- Compromise (in this order) between code clarity, fmax, simplicity and compactness.
- Assumes a memory controller with unknown latency, plug easily to e.g. an SDRAM.
- Predicts next fetched address and indicates whether prediction was correct. The memory controller may exploit this prediction to reach as low as two cycles per instruction.
- Dhrystone CPI: 4.043
- Passes timing at 90 MHz (100 MHZ depending on environment), overclocked successfully at 200 MHz on ULX3S
- Barrel shifter for 1 cycle ALU, implements 32 bits `rdcycle` and `rdinstret`, as well as a special `userdata` hijacking `rdtime` (used as a mechanism to feed auxiliary data to running code).
- Relatively compact, ~2K LUTs on ECP5 (1990 LUTs as of latest).
