#!/bin/bash

git submodule init
git submodule update

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir BUILD
cd BUILD

pacman -S --noconfirm --needed unzip wget perl cmake gcc g++ make

mkdir verilator-framework
cd verilator-framework

export VERILATOR_ROOT=$DIR/tools/fpga-binutils/mingw32/
cmake -G "MinGW Makefiles" ../../frameworks/verilator/
mingw32-make install

cd ..

cd ..
