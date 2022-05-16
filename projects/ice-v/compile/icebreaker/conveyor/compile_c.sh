#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

source ../../tools/bash/find_riscv.sh

echo "using $ARCH"

BASE=./compile/icebreaker/conveyor
DST=./compile/build

# we use ICESTICK below since there is nothing specially done for the icebreaker
$ARCH-gcc -DICESTICK_CONVEYOR -nostartfiles -fstack-reuse=none -fno-builtin -O3 -fno-stack-protector -fno-pic -march=rv32i -mabi=ilp32 -T$BASE/config_c.ld -o $DST/code.elf $BASE/crt0.s $1 -lm

$ARCH-objcopy -O verilog $DST/code.elf $DST/code.hex

# uncomment to see the actual code, useful for debugging
# $ARCH-objcopy.exe -O binary $DST/code.elf $DST/code.bin
# $ARCH-objdump.exe -D -m riscv $DST/code.elf
