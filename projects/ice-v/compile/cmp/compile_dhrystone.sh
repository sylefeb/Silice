#!/bin/bash

set -e

BASE=./compile/cmp
DST=./compile/build

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo $DIR
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

#MAIN=$BASE/test.c # ../fire-v/smoke/dhrystone/dhry.c
MAIN=../fire-v/smoke/dhrystone/dhry.c

source ../../tools/bash/find_riscv.sh

echo "using $ARCH"

echo "Adding mylibc"
# $ARCH-gcc -w -O2 -fno-pic -fno-stack-protector -march=rv32i -mabi=ilp32 -c $BASE/mylibc.c -o $DST/mylibc.o
# OBJECTS="$DST/code.o $DST/div.o $DST/mylibc.o"
# $ARCH-gcc -fno-unroll-loops -O2 -fno-pic -fno-stack-protector -march=rv32i -mabi=ilp32 -c -o $DST/code.o $MAIN
# $ARCH-as -march=rv32i -mabi=ilp32 -o $DST/div.o ../fire-v/smoke/mylibc/div.s
# $ARCH-as -march=rv32i -mabi=ilp32 -o $DST/crt0.o $BASE/crt0.s
# $ARCH-ld -m elf32lriscv -b elf32-littleriscv -T$BASE/config_c.ld --no-relax -o $DST/code.elf $OBJECTS

$ARCH-gcc -fstack-reuse=none -fno-builtin -O3 -fno-stack-protector -fno-pic -march=rv32i -mabi=ilp32 -T$BASE/config_c.ld -ffreestanding -nostdlib -o $DST/code.elf $BASE/crt0.s ../fire-v/smoke/mylibc/div.s $BASE/mylibc.c $MAIN


$ARCH-objcopy -O verilog $DST/code.elf $DST/code.hex

$ARCH-objdump.exe -drwCS $DST/code.elf > $DST/disasm.txt
