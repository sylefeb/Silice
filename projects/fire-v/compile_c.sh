#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

source ../../tools/bash/find_riscv.sh

echo "using $ARCH"

if [ -z "$2" ]; then
  echo "Adding mylibc"
  $ARCH-gcc -w -O2 -fno-pic -march=rv32i -mabi=ilp32 -c smoke/mylibc/mylibc.c -o build/mylibc.o
  OBJECTS="build/code.o build/div.o build/mylibc.o"
  CPU=0
elif [ "$2" == "--nolibc" -o "$3" == "--nolibc" ]; then
  echo "Skipping mylibc"
  OBJECTS="build/code.o"
  if [ "$3" == "--nolibc" ]; then
    CPU=${2:-0}
  else
    CPU=0
  fi
else
  CPU=${2:-0}  
fi

echo "Compiling for CPU $CPU"

$ARCH-gcc -fno-unroll-loops -O2 -fno-pic -march=rv32i -mabi=ilp32 -S $1 -o build/code.s
$ARCH-gcc -fno-unroll-loops -O2 -fno-pic -march=rv32i -mabi=ilp32 -c -o build/code.o $1

$ARCH-as -march=rv32i -mabi=ilp32 -o build/div.o smoke/mylibc/div.s
$ARCH-as -march=rv32i -mabi=ilp32 -o crt0.o smoke/crt0.s

rm build/code0.hex 2> /dev/null
rm build/code1.hex 2> /dev/null

$ARCH-ld -m elf32lriscv -b elf32-littleriscv -Tsmoke/config_cpu$CPU.ld --no-relax -o build/code.elf $OBJECTS
# $ARCH-ld -m elf32lriscv -b elf32-littleriscv -Tsmoke/config_test.ld --no-relax -o build/code.elf $OBJECTS

$ARCH-objcopy -O verilog build/code.elf build/code$CPU.hex

# uncomment to see the actual code, usefull for debugging
# $ARCH-objcopy.exe -O binary build/code.elf build/code.bin
# $ARCH-objdump.exe -D -b binary -m riscv build/code.bin 
