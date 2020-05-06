#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir BUILD
cd BUILD
export VERILATOR_ROOT=$DIR/tools/fpga-binutils/mingw32/
cmake -G "MinGW Makefiles" ../frameworks/verilator/
mingw32-make install
cd ..
rm -rf BUILD
