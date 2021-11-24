#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

source ../../tools/bash/find_riscv.sh

echo "using $ARCH"

$ARCH-gcc -DICESTICK -fstack-reuse=none -fno-builtin -fno-unroll-loops -O1 -fno-stack-protector -fno-pic -march=rv32e -mabi=ilp32e -S $1 -o compile/build/code.s
$ARCH-gcc -DICESTICK -fstack-reuse=none -fno-builtin -fno-unroll-loops -O1 -fno-stack-protector -fno-pic -march=rv32e -mabi=ilp32e -c -o compile/build/code.o $1

$ARCH-as -march=rv32e -mabi=ilp32e -o crt0.o compile/icestick/crt0_dual.s

$ARCH-ld -m elf32lriscv -b elf32-littleriscv -Tcompile/icestick/config_c.ld --no-relax -o compile/build/code.elf compile/build/code.o

$ARCH-objcopy -O verilog compile/build/code.elf compile/build/code.hex

# uncomment to see the actual code, usefull for debugging
# $ARCH-objcopy.exe -O binary compile/build/code.elf compile/build/code.bin
# $ARCH-objdump.exe -D -b binary -m riscv compile/build/code.bin
