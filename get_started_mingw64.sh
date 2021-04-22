#!/bin/bash

pacman -S --noconfirm --needed unzip wget 

wget -c https://github.com/sylefeb/fpga-binutils/releases/download/v20210419-1/fpga-binutils-64.zip 

unzip -o fpga-binutils-64.zip -d tools/fpga-binutils/

rm fpga-binutils-64.zip

./compile_silice_mingw64.sh

DIR=`pwd`
echo 'export PATH=$PATH:'$DIR/bin':'$DIR/tools/fpga-binutils/mingw64/bin >> ~/.bashrc 

echo ""
echo "--------------------------------------------------------------------"
echo "Please start a new shell before using Silice (PATH has been changed)"
echo "--------------------------------------------------------------------"
