#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

if ! type "riscv64-unknown-elf-as" > /dev/null; then
  echo "defaulting to riscv64-linux"
  ARCH="riscv64-linux"
else
  ARCH="riscv64-unknown"
fi

echo "using $ARCH"

$ARCH-elf-as.exe -march=rv32i -mabi=ilp32 -o compile/build/code.o $1
$ARCH-elf-ld.exe -m elf32lriscv -b elf32-littleriscv -Tcompile/config_asm.ld --no-relax -o compile/build/code.elf build/code.o
$ARCH-elf-objcopy.exe -O verilog build/code.elf compile/build/code.hex

# $ARCH-elf-objcopy.exe -O binary compile/build/code.elf compile/build/code.bin
# $ARCH-elf-objdump.exe -D -b binary -m riscv compile/build/code.bin 
