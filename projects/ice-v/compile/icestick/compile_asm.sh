#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

source ../../tools/bash/find_riscv.sh

echo "using $ARCH"

$ARCH-as.exe -march=rv32i -mabi=ilp32 -o compile/build/code.o $1
$ARCH-ld.exe -m elf32lriscv -b elf32-littleriscv -Tcompile/icestick/config_asm.ld --no-relax -o compile/build/code.elf compile/build/code.o
$ARCH-objcopy.exe -O verilog compile/build/code.elf compile/build/code.hex

$ARCH-objcopy.exe -O binary compile/build/code.elf compile/build/code.bin
$ARCH-objdump.exe -D -b binary -m riscv compile/build/code.bin 
