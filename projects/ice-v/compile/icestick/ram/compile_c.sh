#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

source ../../tools/bash/find_riscv.sh

echo "using $ARCH"

BASE=./compile/icestick/ram
DST=./compile/build

$ARCH-as -march=rv32i -mabi=ilp32 -o crt0.o $BASE/crt0.s

$ARCH-gcc -DICESTICK_RAM -nostartfiles -fno-builtin -fno-unroll-loops -O3 -fno-stack-protector -fno-pic -march=rv32i -mabi=ilp32 -T $BASE/config_c.ld -o $DST/code.elf $1 crt0.o -lm

$ARCH-objcopy.exe -O binary $DST/code.elf $DST/code.bin
$ARCH-objdump.exe -D -b binary -m riscv $DST/code.bin
