#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

if ! type "riscv32-unknown-elf-as" > /dev/null; then
  echo "defaulting to riscv64-linux"
  ARCH="riscv64-linux"
else
  ARCH="riscv32-unknown"
fi

echo "using $ARCH"

$ARCH-elf-gcc -w -O2 -fno-pic -DMYLIBC_SMALL -march=rv32i -mabi=ilp32 -c smoke/boot/boot_sdcard.c -o build/boot.o

$ARCH-elf-as -march=rv32i -mabi=ilp32 -o crt0.o smoke/crt0_boot.s

CPU=${2:-0}

rm build/code0.hex 2> /dev/null
rm build/code1.hex 2> /dev/null

$ARCH-elf-ld -m elf32lriscv -b elf32-littleriscv -Tsmoke/config_cpu$CPU.ld --no-relax crt0.o -o build/code.elf build/boot.o

$ARCH-elf-objcopy -O verilog build/code.elf build/code$CPU.hex

# uncomment to see the actual code, usefull for debugging
# $ARCH-elf-objcopy.exe -O binary build/code.elf build/code.bin
# $ARCH-elf-objdump.exe -D -b binary -m riscv build/code.bin 
