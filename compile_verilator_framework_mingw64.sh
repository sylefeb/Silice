#!/bin/bash

git submodule init
git submodule update

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir BUILD
cd BUILD

pacman -S --noconfirm --needed unzip wget perl ${MINGW_PACKAGE_PREFIX}-cmake ${MINGW_PACKAGE_PREFIX}-gcc ${MINGW_PACKAGE_PREFIX}-make

mkdir verilator-framework
cd verilator-framework

export VERILATOR_ROOT=$DIR/tools/fpga-binutils/mingw64/
/mingw64/bin/cmake -G "MinGW Makefiles" ../../frameworks/verilator/
mingw32-make install

cd ..

cd ..
