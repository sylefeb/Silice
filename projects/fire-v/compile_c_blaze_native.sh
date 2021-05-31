#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export PATH=$PATH:$DIR/../../tools/fpga-binutils/mingw32/bin/

if ! type "riscv32-unknown-elf-as" > /dev/null; then
  echo "defaulting to riscv64-linux"
  ARCH="riscv64-linux"
else
  ARCH="riscv32-unknown"
fi

if [[ $RV32IM ]]; then
  riscarch="rv32im"
else
  riscarch="rv32i"
fi

echo "using $ARCH"
echo "targetting $riscarch"

if [ -z "$2" ]; then 
  echo "Adding mylibc"
  $ARCH-elf-gcc -w -O3 -fno-pic -fno-builtin -fno-unroll-loops -march=$riscarch -mabi=ilp32 -c -DBLAZE -DMYLIBC_SMALL smoke/mylibc/mylibc.c -o build/mylibc.o
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

$ARCH-elf-gcc -O3 -fno-pic -fno-builtin -fno-unroll-loops -march=$riscarch -mabi=ilp32 -DBLAZE  -S $1 -o build/code.s
$ARCH-elf-gcc -O3 -fno-pic -fno-builtin -fno-unroll-loops -march=$riscarch -mabi=ilp32 -DBLAZE  -c -o build/code.o $1

$ARCH-elf-as -march=$riscarch -mabi=ilp32 -o build/div.o smoke/mylibc/div.s
$ARCH-elf-as -march=$riscarch -mabi=ilp32 -o crt0.o smoke/crt0.s

rm build/code0.hex 2> /dev/null
rm build/code1.hex 2> /dev/null

$ARCH-elf-ld -m elf32lriscv -b elf32-littleriscv -Tsmoke/config_blaze_boot.ld --no-relax -o build/code.elf $OBJECTS

$ARCH-elf-objcopy -O verilog build/code.elf build/code$CPU.hex

# uncomment to see the actual code, usefull for debugging
# $ARCH-elf-objcopy.exe -O binary build/code.elf build/code.bin
# $ARCH-elf-objdump.exe -D -b binary -m riscv build/code.bin 
