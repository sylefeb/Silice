#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

source ../../tools/bash/find_riscv.sh

echo "using $ARCH"

BASE=./compile/icestick/ice-v
DST=./compile/build

$ARCH-as.exe -march=rv32i -mabi=ilp32 -o $DST/code.o $1
$ARCH-ld.exe -m elf32lriscv -b elf32-littleriscv -T$BASE/config_asm.ld --no-relax -o $DST/code.elf $DST/code.o
$ARCH-objcopy.exe -O verilog $DST/code.elf $DST/code.hex

$ARCH-objcopy.exe -O binary $DST/code.elf $DST/code.bin
$ARCH-objdump.exe -D -b binary -m riscv $DST/code.bin
