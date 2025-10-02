#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

source ../../tools/bash/find_riscv.sh

echo "using $ARCH"

BASE=./compile/cmp
DST=./compile/build

$ARCH-gcc -DICEBREAKER_SWIRL -fstack-reuse=none -fno-builtin -O3 -fno-stack-protector -fno-pic -march=rv32i -mabi=ilp32 -T$BASE/config_c.ld -ffreestanding -nostdlib -o $DST/code.elf $BASE/crt0.s $1

$ARCH-objcopy -O verilog $DST/code.elf $DST/code.hex

$ARCH-objdump.exe -drwCS $DST/code.elf > $DST/disasm.txt
