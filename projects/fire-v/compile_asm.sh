#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

source ../../tools/bash/find_riscv.sh

echo "using $ARCH"

$ARCH-as.exe -march=rv32i -mabi=ilp32 -o build/code.o $1

$ARCH-ld.exe -m elf32lriscv -b elf32-littleriscv -Tsmoke/config_asm.ld --no-relax -o build/code.elf build/code.o

$ARCH-objcopy.exe -O verilog build/code.elf build/code0.hex

# $ARCH-objcopy.exe -O binary build/code.elf build/code.bin
# $ARCH-objdump.exe -D -b binary -m riscv build/code.bin 
