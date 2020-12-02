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

# Following based on FemtoRV compile scripts https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV

$ARCH-elf-as.exe -march=rv32i -mabi=ilp32 -o build/code.o $1

$ARCH-elf-ld.exe -m elf32lriscv -b elf32-littleriscv -Tconfig_asm.ld --no-relax -o build/code.elf build/code.o

$ARCH-elf-objcopy.exe -O verilog build/code.elf build/code.hex

$ARCH-elf-objcopy.exe -O binary build/code.elf build/code.bin
$ARCH-elf-objdump.exe -D -b binary -m riscv build/code.bin 
