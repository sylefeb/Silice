#!/bin/bash
echo "--------------------------------------------------------------------"
echo "This script installs all necessary packages and compiles Silice"
echo "Please refer to the script source code to see the list of packages"
echo "--------------------------------------------------------------------"

read -p "Please type 'y' to go ahead, any other key to exit: " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
	echo
	echo "Exiting."
	exit
fi

pacman -S --noconfirm --needed unzip wget make python3 python-pip ${MINGW_PACKAGE_PREFIX}-riscv64-unknown-elf-toolchain ${MINGW_PACKAGE_PREFIX}-iverilog ${MINGW_PACKAGE_PREFIX}-gtkwave ${MINGW_PACKAGE_PREFIX}-verilator ${MINGW_PACKAGE_PREFIX}-nextpnr ${MINGW_PACKAGE_PREFIX}-dfu-util ${MINGW_PACKAGE_PREFIX}-icestorm ${MINGW_PACKAGE_PREFIX}-prjtrellis ${MINGW_PACKAGE_PREFIX}-openFPGALoader

wget -c https://github.com/sylefeb/fpga-binutils/releases/download/v20210705-2/fpga-binutils-64.zip 

unzip -o fpga-binutils-64.zip -d tools/fpga-binutils/

rm fpga-binutils-64.zip

./compile_silice_mingw64.sh

DIR=`pwd`
echo 'export PATH=$PATH:'$DIR/bin':'$DIR/tools/fpga-binutils/mingw64/bin >> ~/.bashrc 

echo ""
echo "--------------------------------------------------------------------"
echo "Please start a new shell before using Silice (PATH has been changed)"
echo "--------------------------------------------------------------------"
