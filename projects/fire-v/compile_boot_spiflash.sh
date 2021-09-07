#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

source ../../tools/bash/find_riscv.sh

echo "using $ARCH"

$ARCH-gcc -w -O2 -fno-pic -DMYLIBC_SMALL -march=rv32i -mabi=ilp32 -c smoke/boot/boot_spiflash.c -o build/boot.o

$ARCH-as -march=rv32i -mabi=ilp32 -o crt0.o smoke/crt0.s

CPU=${2:-0}

rm build/code0.hex 2> /dev/null
rm build/code1.hex 2> /dev/null

$ARCH-ld -m elf32lriscv -b elf32-littleriscv -Tsmoke/config_blaze_boot.ld --no-relax crt0.o -o build/code.elf build/boot.o

$ARCH-objcopy -O verilog build/code.elf build/code$CPU.hex

# uncomment to see the actual code, usefull for debugging
# $ARCH-objcopy.exe -O binary build/code.elf build/code.bin
# $ARCH-objdump.exe -D -b binary -m riscv build/code.bin 
