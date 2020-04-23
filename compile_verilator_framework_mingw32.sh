#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir BUILD
cd BUILD
export VERILATOR_ROOT=$DIR/tools/fpga-binutils/mingw32/
cmake -G "MSYS Makefiles" ../frameworks/verilator/
make install
cd ..
rm -rf BUILD
