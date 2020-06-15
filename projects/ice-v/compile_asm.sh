#!/bin/bash

# Based on @BrunoLevy01 FemtoRV compile scripts, https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV

./risc-v/bin/riscv64-unknown-elf-as.exe -march=rv32i -mabi=ilp32 -o code.o $1

./risc-v/bin/riscv64-unknown-elf-ld.exe -m elf32lriscv -b elf32-littleriscv -Tconfig_asm.ld --no-relax -o code.elf code.o

./risc-v/bin/riscv64-unknown-elf-objcopy.exe -O verilog code.elf code.hex

./risc-v/bin/riscv64-unknown-elf-objcopy.exe -O binary code.elf code.bin
./risc-v/bin/riscv64-unknown-elf-objdump.exe -D -b binary -m riscv code.bin 
