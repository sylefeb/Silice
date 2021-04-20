#!/bin/bash

pacman -S --noconfirm --needed unzip wget 

wget -c https://github.com/sylefeb/fpga-binutils/releases/download/v20210419-1/fpga-binutils-64.zip 

unzip -o fpga-binutils-64.zip -d tools/fpga-binutils/

./compile_silice_mingw64.sh

./compile_verilator_framework_mingw64.sh
