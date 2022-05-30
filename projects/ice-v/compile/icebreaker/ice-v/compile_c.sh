#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

source ../../tools/bash/find_riscv.sh

echo "using $ARCH"

BASE=./compile/icebreaker/ice-v
DST=./compile/build

# we use ICESTICK below since there is nothing specially done for the icebreaker
$ARCH-gcc -DICESTICK -fno-builtin -fno-unroll-loops -O3 -fno-stack-protector -fno-pic -march=rv32i -mabi=ilp32 -S $1 -o $DST/code.s
$ARCH-gcc -DICESTICK -fno-builtin -fno-unroll-loops -O3 -fno-stack-protector -fno-pic -march=rv32i -mabi=ilp32 -c -o $DST/code.o $1

$ARCH-as -march=rv32i -mabi=ilp32 -o crt0.o $BASE/crt0.s

$ARCH-ld -m elf32lriscv -b elf32-littleriscv -T$BASE/config_c.ld --no-relax -o $DST/code.elf $DST/code.o

$ARCH-objcopy -O verilog $DST/code.elf $DST/code.hex

# uncomment to see the actual code, useful for debugging
$ARCH-objcopy.exe -O binary $DST/code.elf $DST/code.bin
$ARCH-objdump.exe -D -b binary -m riscv $DST/code.bin
